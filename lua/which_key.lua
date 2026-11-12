-- Show continuations of mapped prefixes in Normal and Visual modes.
--
-- Call setup() after defining bindings, as in init.lua. It keeps per-buffer,
-- per-mode indexes of global and local mappings and owns buffer-local triggers
-- for eligible roots without exact mappings. Binding actions belong to
-- lua/keymaps.lua and their defining modules; native mapping timeouts control
-- the hint delay configured in lua/options.lua.
--
-- A trigger shows a panel without taking focus and reads continuation keys.
-- Completed input returns to native mapping resolution with its trigger detached
-- to prevent recursion. SafeState restores triggers after resolution finishes;
-- context changes cancel an open panel.
--
-- show(prefix) handles a prefix explicitly, refresh() rediscovers mappings, and
-- disable() releases owned resources. See :help better-start-nvim-which-key for
-- options, trigger exclusions, and input semantics.
local M = {}
local api, fn = vim.api, vim.fn
local defaults = {
	modes = { 'n', 'x' },
	groups = {},
	max_height = 12,
	min_column_width = 30,
	page_down = '<C-d>',
	page_up = '<C-u>',
}
local state = { caches = {}, generation = 0 }
local ns = api.nvim_create_namespace 'native-which-key'
local replay

local function raw(lhs)
	return vim.keycode(lhs)
end

-- A modifier prefix and its following key are one token, as are UTF-8 characters.
local function tokens(keys)
	local result, i = {}, 1
	while i <= #keys do
		local start = i
		if keys:byte(i) == 128 and keys:byte(i + 1) == 252 then
			i = i + 3
		end
		local byte = keys:byte(i)
		if not byte then
			break
		end
		i = i + (byte == 128 and 3 or byte < 192 and 1 or byte < 224 and 2 or byte < 240 and 3 or 4)
		result[#result + 1] = keys:sub(start, i - 1)
	end
	return result
end

local function mode()
	local current = api.nvim_get_mode().mode
	if current == 'n' or current == 'nt' or current == 'ntT' then
		return 'n'
	elseif current == 'v' or current == 'V' or current == '\22' then
		return 'x'
	end
end

local function hide()
	if state.win and api.nvim_win_is_valid(state.win) then
		api.nvim_win_close(state.win, true)
	end
	state.win = nil
end

local function cancel()
	local active = state.active
	if active and not active.cancelled then
		active.cancelled = true
		-- Wake a blocked getchar without consuming the next real input key.
		if active.reading then
			api.nvim_feedkeys(raw '<Esc>', 'ni', false)
		end
	end
	hide()
end

local function detach(buf, mapping_mode, only_key)
	local cache = state.caches[buf]
	if not cache or not api.nvim_buf_is_valid(buf) then
		return
	end
	for _, m in ipairs(mapping_mode and { mapping_mode } or state.opts.modes) do
		local index = cache[m]
		if index then
			for _, map in ipairs(api.nvim_buf_get_keymap(buf, m)) do
				local key = raw(map.lhs)
				if (not only_key or key == only_key) and index.owned[key] and map.callback == index.owned[key] then
					vim.keymap.del(m, map.lhs, { buffer = buf })
					index.owned[key] = nil
				end
			end
		end
	end
end

local function build(buf, mapping_mode)
	local maps = {}
	for _, list in ipairs { api.nvim_get_keymap(mapping_mode), api.nvim_buf_get_keymap(buf, mapping_mode) } do
		for _, map in ipairs(list) do
			local key = raw(map.lhs)
			if not key:find(raw '<Plug>', 1, true) and not key:find(raw '<SNR>', 1, true) then
				maps[key] = map
			end
		end
	end
	local root = { children = {}, count = 0 }
	for key, map in pairs(maps) do
		local node = root
		for _, token in ipairs(tokens(key)) do
			node.count = node.count + 1
			node.children[token] = node.children[token] or { children = {}, count = 0 }
			node = node.children[token]
		end
		node.count = node.count + 1
		node.map = map
	end
	return { root = root, owned = {} }
end

local function node_at(root, prefix)
	local node = root
	for _, token in ipairs(tokens(prefix)) do
		node = node.children[token]
		if not node then
			return
		end
	end
	return node
end

local function label(map)
	return map.desc or (map.rhs and map.rhs ~= '' and map.rhs) or 'Lua callback'
end

local function entries(node, prefix)
	local result = {}
	for key, child in pairs(node.children) do
		local group = state.groups[prefix .. key]
		result[#result + 1] = {
			key = fn.keytrans(key),
			text = child.map and label(child.map) or ('+ ' .. (group or (child.count .. ' mappings'))),
		}
	end
	table.sort(result, function(a, b)
		return a.key < b.key
	end)
	return result
end

local function fit(text, width)
	text = text:gsub('[\r\n\t]', ' ')
	if fn.strdisplaywidth(text) <= width then
		return text
	end
	local lo, hi = 0, fn.strchars(text)
	while lo < hi do
		local mid = math.ceil((lo + hi) / 2)
		if fn.strdisplaywidth(fn.strcharpart(text, 0, mid)) <= width - 1 then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return fn.strcharpart(text, 0, lo) .. '…'
end

local function render(active, node)
	local items = entries(node, active.prefix)
	if #items == 0 or vim.o.lines < 5 or vim.o.columns < 10 then
		hide()
		return
	end
	local width = math.max(1, vim.o.columns - 2)
	local cols = math.max(1, math.floor(width / state.opts.min_column_width))
	cols = math.min(cols, #items)
	local cell = math.floor(width / cols)
	local rows = math.min(math.ceil(#items / cols), state.opts.max_height - 1, vim.o.lines - 4)
	local size = rows * cols
	local pages = math.ceil(#items / size)
	active.page = math.min(active.page or 1, pages)
	active.pages = pages
	active.down = not node.children[raw(state.opts.page_down)] and raw(state.opts.page_down) or nil
	active.up = not node.children[raw(state.opts.page_up)] and raw(state.opts.page_up) or nil
	local title = fn.keytrans(active.prefix)
	if state.groups[active.prefix] then
		title = title .. ' — ' .. state.groups[active.prefix]
	end
	if pages > 1 then
		title = title .. ('  [%d/%d]'):format(active.page, pages)
		if active.down then
			title = title .. '  ' .. state.opts.page_down .. ' next'
		end
		if active.up then
			title = title .. '  ' .. state.opts.page_up .. ' previous'
		end
	end
	local lines, highlights = { fit(title, width) }, {}
	for row = 1, rows do
		local line = ''
		for col = 1, cols do
			local item = items[(active.page - 1) * size + (col - 1) * rows + row]
			if item then
				local text = fit(item.key .. '  ' .. item.text, cell - 2)
				highlights[#highlights + 1] = { row, #line, #line + math.min(#item.key, #text) }
				line = line .. text .. string.rep(' ', cell - fn.strdisplaywidth(text))
			end
		end
		lines[#lines + 1] = line
	end
	if not state.buf or not api.nvim_buf_is_valid(state.buf) then
		state.buf = api.nvim_create_buf(false, true)
		vim.bo[state.buf].bufhidden = 'hide'
		vim.bo[state.buf].filetype = 'which-key'
	end
	api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
	api.nvim_buf_set_extmark(state.buf, ns, 0, 0, { end_row = 1, hl_group = 'Title' })
	for _, hl in ipairs(highlights) do
		api.nvim_buf_set_extmark(state.buf, ns, hl[1], hl[2], { end_col = hl[3], hl_group = 'Special' })
	end
	local config = {
		relative = 'editor',
		row = math.max(0, vim.o.lines - #lines - math.max(1, vim.o.cmdheight) - 1),
		col = 1,
		width = width,
		height = #lines,
		style = 'minimal',
		focusable = false,
		border = 'none',
		zindex = 60,
		noautocmd = true,
	}
	if state.win and api.nvim_win_is_valid(state.win) then
		api.nvim_win_set_config(state.win, config)
	else
		state.win = api.nvim_open_win(state.buf, false, config)
		vim.wo[state.win].winhighlight = 'Normal:NormalFloat'
		vim.wo[state.win].wrap = false
	end
	vim.cmd.redraw()
end

local function attach(buf, mapping_mode, index)
	for key, child in pairs(index.root.children) do
		-- Counts, registers, operators and cancellation keep their native entry points.
		local unsafe = key:match '^[0-9"\27]$' or key == raw '<C-c>' or (mapping_mode == 'n' and key:match '^[dcyrq@]$')
		if not child.map and next(child.children) and not unsafe then
			local callback = function()
				if api.nvim_get_mode().mode:match '^ni' then
					-- A <C-o> command returns to Insert when this callback finishes.
					replay {
						buf = buf,
						mode = mapping_mode,
						prefix = key,
						count = vim.v.count,
						register = vim.v.register,
						temporary = true,
					}
					return
				end
				M.show(fn.keytrans(key))
			end
			vim.keymap.set(mapping_mode, fn.keytrans(key), callback, {
				buffer = buf,
				silent = true,
				desc = 'Which-key prefix',
			})
			index.owned[key] = callback
		end
	end
end

-- Reindex current-buffer mappings and replace owned triggers; no-op when disabled.
-- An active panel or native replay defers the refresh until it can safely run.
function M.refresh()
	if not state.enabled then
		return
	end
	if state.replaying or state.active then
		state.pending = true
		return
	end
	local buf = api.nvim_get_current_buf()
	if buf == state.buf then
		return
	end
	detach(buf)
	local cache = {}
	state.caches[buf] = cache
	for _, m in ipairs(state.opts.modes) do
		cache[m] = build(buf, m)
		attach(buf, m, cache[m])
	end
	state.pending = false
end

local function request_refresh()
	if state.queued then
		return
	end
	state.queued = true
	local generation = state.generation
	vim.schedule(function()
		if state.generation == generation then
			state.queued = false
			M.refresh()
		end
	end)
end

replay = function(active)
	detach(active.buf, active.mode, tokens(active.prefix)[1])
	state.replaying = true
	local context = (active.register ~= '"' and '"' .. active.register or '')
		.. (active.count > 0 and tostring(active.count) or '')
	-- SafeState reinstalls triggers only after Neovim finishes resolving the input.
	api.nvim_feedkeys((active.temporary and raw '<C-o>' or '') .. context .. active.prefix, 'mi', false)
end

-- Handle a prefix in Vim key notation (e.g. '<leader>p'), waiting for continuation
-- keys as needed. Feed completed input to native mappings; return no selection.
-- No-op when disabled, another panel is active, or the current mode is unsupported.
function M.show(prefix)
	local mapping_mode = mode()
	if not state.enabled or state.active or not vim.tbl_contains(state.opts.modes, mapping_mode) then
		return
	end
	local active = {
		buf = api.nvim_get_current_buf(),
		win = api.nvim_get_current_win(),
		mode = mapping_mode,
		prefix = raw(prefix),
		count = vim.v.count,
		register = vim.v.register,
		page = 1,
	}
	state.replaying = false
	M.refresh()
	state.active = active
	local ok, err = xpcall(function()
		local root = state.caches[active.buf][mapping_mode].root
		while not active.cancelled do
			local node = node_at(root, active.prefix)
			if not node or node.map or not next(node.children) or fn.reg_executing() ~= '' then
				break
			end
			-- Drain already typed keys before rendering; fast mappings never flash a panel.
			local key = fn.getcharstr(0)
			if key == '' then
				render(active, node)
				active.reading = true
				key = fn.getcharstr()
				active.reading = false
			end
			if active.cancelled or key == raw '<Esc>' or key == raw '<C-c>' then
				active.cancel_key = not active.cancelled and key or nil
				active.cancelled = true
				break
			end
			if active.pages and active.pages > 1 and (key == active.down or key == active.up) then
				active.page = (active.page - 1 + (key == active.down and 1 or -1)) % active.pages + 1
			else
				active.prefix = active.prefix .. key
				active.page, active.pages = 1, nil
			end
		end
	end, debug.traceback)
	hide()
	state.active = nil
	if not ok then
		active.cancelled = true
		-- CTRL-C interrupts getchar with an error; it is cancellation, not a failure.
		if tostring(err):find('Keyboard interrupt', 1, true) or tostring(err):find('Vim:Interrupt', 1, true) then
			-- getchar consumes the interrupt; also leave Visual mode as native CTRL-C would.
			active.cancel_key = raw '<Esc>'
		else
			vim.notify('Which-key: ' .. tostring(err), vim.log.levels.ERROR)
		end
	end
	if not active.cancelled and state.enabled and api.nvim_get_current_buf() == active.buf then
		replay(active)
	else
		if active.cancel_key and api.nvim_get_current_buf() == active.buf then
			api.nvim_feedkeys(active.cancel_key, 'ni', false)
		end
		if state.pending then
			request_refresh()
		end
	end
end

-- Cancel input and remove owned triggers, autocommands, and scratch resources.
-- Preserve mappings that have replaced an owned trigger.
function M.disable()
	cancel()
	for buf in pairs(state.caches) do
		detach(buf)
	end
	if state.augroup then
		api.nvim_del_augroup_by_id(state.augroup)
	end
	if state.buf and api.nvim_buf_is_valid(state.buf) then
		api.nvim_buf_delete(state.buf, { force = true })
	end
	state = { caches = {}, generation = state.generation + 1 }
end

-- Replace any previous setup; opts overrides defaults above. See the help for
-- option details. Only n (Normal) and x (Visual) modes are supported; invalid
-- modes or panel dimensions raise an error.
function M.setup(opts)
	M.disable()
	state.opts = vim.tbl_deep_extend('force', defaults, opts or {})
	assert(state.opts.max_height >= 2 and state.opts.min_column_width >= 8, 'Invalid which-key panel dimensions')
	for _, m in ipairs(state.opts.modes) do
		assert(m == 'n' or m == 'x', 'Which-key supports n and x modes')
	end
	state.groups = {}
	for key, name in pairs(state.opts.groups) do
		state.groups[raw(key)] = name
	end
	state.enabled = true
	state.augroup = api.nvim_create_augroup('NativeWhichKey', { clear = true })
	api.nvim_create_autocmd(
		{ 'VimEnter', 'BufEnter', 'FileType', 'LspAttach', 'LspDetach', 'SourcePost', 'PackChanged' },
		{
			group = state.augroup,
			callback = request_refresh,
		}
	)
	api.nvim_create_autocmd('SafeState', {
		group = state.augroup,
		callback = function()
			if state.replaying then
				state.replaying = false
				M.refresh()
			end
		end,
	})
	api.nvim_create_autocmd({ 'BufLeave', 'WinLeave', 'TabLeave' }, { group = state.augroup, callback = cancel })
	api.nvim_create_autocmd('ModeChanged', {
		group = state.augroup,
		callback = function()
			if state.active and mode() ~= state.active.mode then
				cancel()
			end
		end,
	})
	api.nvim_create_autocmd('VimResized', {
		group = state.augroup,
		callback = function()
			local active = state.active
			if active and not active.cancelled then
				local node = node_at(state.caches[active.buf][active.mode].root, active.prefix)
				if node then
					render(active, node)
				end
			end
		end,
	})
	api.nvim_create_autocmd('BufWipeout', {
		group = state.augroup,
		callback = function(ev)
			state.caches[ev.buf] = nil
		end,
	})
	M.refresh()
end

return M
