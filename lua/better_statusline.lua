local M = {}
local api = vim.api
local state
local sep = '  ·  '
local function escape(text)
	return tostring(text):gsub('[\r\n]', ' '):gsub('%%', '%%%%')
end
local function target()
	local win = tonumber(vim.g.statusline_winid)
	return win and api.nvim_win_is_valid(win) and win or api.nvim_get_current_win()
end

-- Rendering performs no discovery, filesystem access, or diagnostic/LSP queries.
function M.statusline()
	return state and state.status or ''
end
function M.winbar()
	return state and state.bars[target()] or ''
end
function M.tabline()
	return state and state.tabs or ''
end

local modes = {
	n = 'NORMAL',
	no = 'O-PENDING',
	i = 'INSERT',
	ic = 'INSERT',
	ix = 'INSERT',
	v = 'VISUAL',
	V = 'V-LINE',
	['\22'] = 'V-BLOCK',
	s = 'SELECT',
	S = 'S-LINE',
	['\19'] = 'S-BLOCK',
	R = 'REPLACE',
	Rv = 'V-REPLACE',
	c = 'COMMAND',
	r = 'PROMPT',
	rm = 'MORE',
	['r?'] = 'CONFIRM',
	['!'] = 'SHELL',
	t = 'TERMINAL',
}
local spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
local request

local function highlights()
	for name, link in pairs {
		Mode = 'StatusLine',
		Error = 'DiagnosticError',
		Warn = 'DiagnosticWarn',
		Info = 'DiagnosticInfo',
		Hint = 'DiagnosticHint',
		Add = 'GitSignsAdd',
		Change = 'GitSignsChange',
		Delete = 'GitSignsDelete',
	} do
		api.nvim_set_hl(0, 'BetterStatusline' .. name, { link = link })
	end
end

local function branch(dir)
	local s = state
	local entry = s.git[dir]
	local now = vim.uv.now()
	if not entry then
		entry = { text = '', time = -math.huge }
		s.git[dir] = entry
	end
	if not entry.pending and now - entry.time > 2000 then
		entry.pending, entry.time = true, now
		-- argv avoids shell interpolation; timeout bounds work on slow filesystems.
		local function finish(result)
			vim.schedule(function()
				if state ~= s then
					return
				end
				entry.pending = false
				local text = result.code == 0 and vim.trim(result.stdout or '') or ''
				if entry.text ~= text then
					entry.text = text
					request()
				end
			end)
		end
		local ok = pcall(
			vim.system,
			{ 'git', '-C', dir, 'rev-parse', '--abbrev-ref', 'HEAD' },
			{ text = true, timeout = 1500 },
			function(result)
				if result.code == 0 and vim.trim(result.stdout or '') == 'HEAD' then
					vim.system(
						{ 'git', '-C', dir, 'rev-parse', '--short=6', 'HEAD' },
						{ text = true, timeout = 1500 },
						finish
					)
				else
					finish(result)
				end
			end
		)
		if not ok then
			entry.pending = false
		end
	end
	return entry.text
end

-- Keep only hunk headers, not a potentially large patch, in memory.
local function diff(name)
	local s = state
	if name == '' or vim.bo.buftype ~= '' then
		return {}
	end
	local entry = s.diffs[name]
	if entry then
		return entry
	end
	entry = {}
	s.diffs[name] = entry
	local counts = { added = 0, changed = 0, removed = 0 }
	local tail = ''
	local ok = pcall(vim.system, {
		'git',
		'-C',
		vim.fn.fnamemodify(name, ':h'),
		'--no-pager',
		'--literal-pathspecs',
		'diff',
		'--no-color',
		'--no-ext-diff',
		'--no-textconv',
		'-U0',
		'--',
		vim.fn.fnamemodify(name, ':t'),
	}, {
		timeout = 2000,
		stdout = function(_, chunk)
			if not chunk then
				return
			end
			local text = tail .. chunk
			local offset = 1
			while true do
				local ending = text:find('\n', offset, true)
				if not ending then
					break
				end
				local header = text:sub(offset, math.min(ending - 1, offset + 128))
				local old, old_count, new, new_count = header:match '^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@'
				offset = ending + 1
				if old and new then
					local removed = tonumber(old_count) or 1
					local added = tonumber(new_count) or 1
					local changed = math.min(removed, added)
					counts.changed = counts.changed + changed
					counts.added = counts.added + added - changed
					counts.removed = counts.removed + removed - changed
				end
			end
			-- Long source lines cannot be hunk headers.
			tail = #text - offset > 512 and 'ignored' or text:sub(offset)
		end,
	}, function(result)
		vim.schedule(function()
			if state ~= s or s.diffs[name] ~= entry then
				return
			end
			if result.code == 0 then
				for key, value in pairs(counts) do
					entry[key] = value
				end
			end
			request()
		end)
	end)
	if not ok then
		s.diffs[name] = entry
	end
	return entry
end

local function lsp(buf)
	local parts, seen = {}, {}
	for _, client in ipairs(vim.lsp.get_clients { bufnr = buf }) do
		if not seen[client.name] then
			seen[client.name] = true
			local work = state.work[client.id]
			local mark = work and (next(work) and spinner[state.frame] or '✓') or ''
			parts[#parts + 1] = escape(client.name) .. (mark ~= '' and ' ' .. mark or '')
		end
	end
	return #parts > 0 and ' ' .. table.concat(parts, '+') or ''
end

local function bar(win, buf)
	local bo = vim.bo[buf]
	if bo.buftype == 'terminal' or bo.filetype == 'terminal' then
		return ''
	end
	local name = api.nvim_buf_get_name(buf)
	local path = name == '' and '- NO NAME -'
		or api.nvim_win_call(win, function()
			return vim.fn.fnamemodify(name, ':~:.')
		end)
	local left = escape(path)
		.. (bo.modified and ' ●' or '')
		.. ((bo.readonly or not bo.modifiable) and ' 󰌾' or '')
	local right, counts = {}, vim.diagnostic.count(buf)
	for i, item in ipairs { { 'Error', '●' }, { 'Warn', '●' }, { 'Info', '○' }, { 'Hint', '⊙' } } do
		if (counts[i] or 0) > 0 then
			right[#right + 1] = '%#BetterStatusline' .. item[1] .. '#' .. item[2] .. ' ' .. counts[i] .. '%*'
		end
	end
	local clients = lsp(buf)
	if clients ~= '' then
		right[#right + 1] = clients
	end
	if bo.filetype ~= '' then
		right[#right + 1] = escape(bo.filetype)
	end
	return ' %<' .. left .. '%=' .. table.concat(right, sep) .. ' '
end

local function tablabel(tab)
	local buf = api.nvim_win_get_buf(api.nvim_tabpage_get_win(tab))
	local name, bo = api.nvim_buf_get_name(buf), vim.bo[buf]
	local custom = vim.t[tab].tabname
	if custom and custom ~= '' then
		return custom
	end
	if bo.filetype == 'fugitive' then
		return 'fugitive: ' .. vim.fn.fnamemodify(name, ':h:h:t')
	end
	if bo.buftype == 'help' then
		return 'help:' .. vim.fn.fnamemodify(name, ':t:r')
	end
	if bo.buftype == 'terminal' then
		return vim.fn.fnamemodify(vim.o.shell, ':t')
	end
	return name == '' and '[No Name]' or vim.fn.fnamemodify(name, ':t')
end

local function refresh()
	local s, tabs = state, {}
	local bars = {}
	for _, win in ipairs(api.nvim_list_wins()) do
		if api.nvim_win_get_config(win).relative == '' then
			local buf = api.nvim_win_get_buf(win)
			bars[win] = bar(win, buf)
			local value = bars[win] == '' and '' or "%!v:lua.require'better_statusline'.winbar()"
			if vim.wo[win].winbar ~= value then
				vim.wo[win].winbar = value
			end
		end
	end
	s.bars = bars
	for nr, tab in ipairs(api.nvim_list_tabpages()) do
		local modified = false
		for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
			modified = modified or vim.bo[api.nvim_win_get_buf(win)].modified
		end
		tabs[#tabs + 1] = (tab == api.nvim_get_current_tabpage() and '%<%#TabLineSel#' or '%#TabLine#')
			.. '%'
			.. nr
			.. 'T '
			.. nr
			.. (modified and '[+]' or '')
			.. ' '
			.. escape(tablabel(tab))
			.. ' %T'
	end
	s.tabs = table.concat(tabs) .. '%#TabLineFill#%='
	local buf = api.nvim_get_current_buf()
	local gs = vim.b[buf].gitsigns_status_dict or {}
	local head = gs.head or vim.b[buf].gitsigns_head
	if not head or head == '' then
		local name = api.nvim_buf_get_name(buf)
		local dir = vim.bo[buf].buftype == '' and name ~= '' and vim.fn.fnamemodify(name, ':h') or vim.fn.getcwd()
		head = branch(dir)
	end
	local parts = {}
	local mode = api.nvim_get_mode().mode
	parts[1] = '%#BetterStatuslineMode#'
		.. (modes[mode] or modes[mode:sub(1, 2)] or modes[mode:sub(1, 1)] or mode)
		.. '%*'
	if head ~= '' then
		parts[#parts + 1] = ' ' .. escape(head)
	end
	local changes = diff(api.nvim_buf_get_name(buf))
	local diff = {}
	for _, item in ipairs { { 'added', '+', 'Add' }, { 'changed', '~', 'Change' }, { 'removed', '-', 'Delete' } } do
		if (changes[item[1]] or 0) > 0 then
			diff[#diff + 1] = '%#BetterStatusline' .. item[3] .. '#' .. item[2] .. changes[item[1]] .. '%*'
		end
	end
	if #diff > 0 then
		parts[#parts + 1] = table.concat(diff, ' ')
	end
	s.status = ' ' .. table.concat(parts, sep) .. '%<%=%3l:%-2c' .. sep .. '🕰 ' .. os.date '%H:%M' .. ' '
	vim.cmd.redrawstatus()
	vim.cmd.redrawtabline()
end

-- One trailing refresh per burst, never one callback per keystroke.
request = function()
	local s = state
	if not s or s.pending then
		return
	end
	s.pending = true
	vim.defer_fn(function()
		if state ~= s then
			return
		end
		s.pending = false
		refresh()
	end, 40)
end
M.refresh = request

function M.setup()
	if state then
		state.timer:stop()
		state.timer:close()
	end
	state = { bars = {}, git = {}, diffs = {}, work = {}, frame = 1 }
	local s = state
	local group = api.nvim_create_augroup('BetterStatusline', { clear = true })
	local function on(events, opts)
		opts.group = group
		api.nvim_create_autocmd(events, opts)
	end
	highlights()
	vim.o.laststatus, vim.o.showtabline = 3, 1
	vim.o.statusline = "%!v:lua.require'better_statusline'.statusline()"
	vim.o.tabline = "%!v:lua.require'better_statusline'.tabline()"
	on({
		'BufEnter',
		'BufWinEnter',
		'WinEnter',
		'WinClosed',
		'TabEnter',
		'TabClosed',
		'BufFilePost',
		'BufModifiedSet',
		'BufWritePost',
		'FileType',
		'DiagnosticChanged',
		'LspAttach',
		'LspDetach',
		'ModeChanged',
		'DirChanged',
		'FocusGained',
		'TermOpen',
		'VimResized',
	}, { callback = request })
	on({ 'BufEnter', 'BufWritePost', 'FocusGained' }, {
		callback = function(ev)
			s.diffs[api.nvim_buf_get_name(ev.buf)] = nil
			request()
		end,
	})
	on('OptionSet', { pattern = { 'readonly', 'modifiable', 'buftype' }, callback = request })
	on('User', { pattern = 'GitSignsUpdate', callback = request })
	on('User', {
		pattern = 'FugitiveChanged',
		callback = function()
			s.diffs = {}
			for _, entry in pairs(s.git) do
				entry.time = -math.huge
			end
			request()
		end,
	})
	on('ColorScheme', {
		callback = function()
			highlights()
			request()
		end,
	})
	on('LspProgress', {
		callback = function(ev)
			local data = ev.data
			local value = data.params.value
			if type(value) ~= 'table' or not value.kind then
				return
			end
			local work = s.work[data.client_id] or {}
			s.work[data.client_id] = work
			work[data.params.token] = value.kind ~= 'end' and true or nil
			request()
		end,
	})
	on('LspDetach', {
		callback = function(ev)
			-- Detach is buffer-local: retain progress while the client serves other buffers.
			vim.schedule(function()
				if state == s and not vim.lsp.get_client_by_id(ev.data.client_id) then
					s.work[ev.data.client_id] = nil
				end
			end)
		end,
	})
	local minute = os.date '%H:%M'
	s.timer = vim.uv.new_timer()
	s.timer:start(
		1000,
		1000,
		vim.schedule_wrap(function()
			if state ~= s then
				return
			end
			local current = os.date '%H:%M'
			local busy = false
			for id, work in pairs(s.work) do
				if not vim.lsp.get_client_by_id(id) then
					s.work[id] = nil
				elseif next(work) then
					busy = true
				end
			end
			if busy then
				s.frame = s.frame % #spinner + 1
			end
			if busy or minute ~= current then
				minute = current
				request()
			end
		end)
	)
	on('VimLeavePre', {
		callback = function()
			s.timer:stop()
			s.timer:close()
		end,
	})
	refresh()
end

return M
