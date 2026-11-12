---@mod better_statusline Native statusline, window bars, and tabline
---@brief [[
---Display editor information in Neovim's native statusline, window bars, and tabline.
---
---Requires Neovim 0.12+ and the Rust library: run `cargo build --release` before
---importing this module. Call setup() once to install all three bars. This repository
---already calls setup() in lua/ui.lua; edit that call to customize it.
---
---Editor events queue updates to cached bar strings; redraws read those strings.
---Git results arrive asynchronously, so their display may lag behind an event.
---Call refresh() after changing metadata directly, such as a custom tab name.
---
---For standalone use: >lua
---  require('better_statusline').setup()
---<
---See |better-start-nvim-statusline| for displayed information, configuration,
---update behavior, and verification instructions.
---@brief ]]
local M = {}
local api = vim.api
local native_git = require 'ffi.git'

---@class BetterStatuslineGit
---@field text string Formatted branch and repository status.
---@field last_request_ms number Timestamp from vim.uv.now().
---@field pending? boolean

---@class BetterStatuslineState
---@field statusline? string
---@field winbars table<integer, string> Keyed by window ID.
---@field tabline? string
---@field repositories table<string, BetterStatuslineGit?> Keyed by directory.
---@field progress_tokens table<integer, table<string|integer, boolean>> Token sets keyed by client ID.
---@field frame integer
---@field mode_colors table<string, string|table> Highlight group names or attribute overrides by mode family.
---@field refresh_pending? boolean
---@field timer uv.uv_timer_t

---Each setup gets a new table so callbacks can reject results from a previous setup.
---@type BetterStatuslineState?
local state

local separator = '  '

---@param text any
---@return string text Single-line text safe inside a native bar format.
---@return integer
local function escape_text(text)
	return tostring(text):gsub('[\r\n]', ' '):gsub('%%', '%%%%')
end

---@return integer win Render target, falling back to the current window if unavailable.
local function target_window()
	-- Use the window being drawn, which may differ from the focused window.
	local win = tonumber(vim.g.statusline_winid)
	---@cast win integer?
	return win and api.nvim_win_is_valid(win) and win or api.nvim_get_current_win()
end

---Return the cached global statusline for the current buffer and mode.
---Installed by setup() as Neovim's statusline callback; calling it does not refresh
---the cache. The result is a native format string, not plain display text.
---@return string format Empty before setup.
function M.statusline()
	return state and state.statusline or ''
end

---Return the cached winbar for the window Neovim is drawing.
---Installed by setup(); falls back to the current window when Neovim supplies no
---valid render target. Calling it does not refresh the cache.
---@return string format Native format string; empty before setup, for terminals, or for an uncached window.
function M.winbar()
	return state and state.winbars[target_window()] or ''
end

---Return the cached tabline, including native mouse targets for switching tabs.
---Installed by setup() as Neovim's tabline callback; calling it does not refresh
---the cache. Visibility is controlled by Neovim's showtabline option.
---@return string format Native format string, or empty before setup.
function M.tabline()
	return state and state.tabline or ''
end

local mode_labels = {
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
local mode_families = {
	n = 'normal',
	i = 'insert',
	v = 'visual',
	V = 'visual',
	['\22'] = 'visual',
	s = 'select',
	S = 'select',
	['\19'] = 'select',
	R = 'replace',
	c = 'command',
	r = 'command',
	['!'] = 'terminal',
	t = 'terminal',
}
local valid_families = { 'normal', 'insert', 'visual', 'select', 'replace', 'command', 'terminal', 'operator' }

---@param mode string Mode code returned by nvim_get_mode().
---@return string group Highlight group name.
local function mode_highlight(mode)
	-- `no` starts with `n` but means operator-pending (for example, after `d`),
	-- so handle it before grouping the remaining modes by their first character.
	local family = mode:sub(1, 2) == 'no' and 'operator' or mode_families[mode:sub(1, 1)] or 'normal'
	return 'BetterStatuslineMode_' .. family
end

---@type fun()
local request_refresh

local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift
local floor = math.floor

---@param fg integer Foreground color packed as 0xRRGGBB.
---@param bg integer Background color packed as 0xRRGGBB.
---@param amount number Foreground weight from 0 (background) to 1 (foreground).
---@return integer color Blended color packed as 0xRRGGBB.
local function blend_rgb(fg, bg, amount)
	local r, g, b = band(rshift(bg, 16), 0xff), band(rshift(bg, 8), 0xff), band(bg, 0xff)
	r = floor(r + (band(rshift(fg, 16), 0xff) - r) * amount + 0.5)
	g = floor(g + (band(rshift(fg, 8), 0xff) - g) * amount + 0.5)
	b = floor(b + (band(fg, 0xff) - b) * amount + 0.5)
	return bor(lshift(r, 16), lshift(g, 8), b)
end

local shimmer_opacity = { 0.45, 0.7, 1 }

--- Padding lets the bright band enter and leave gradually instead of jumping between ends.
--- It adds positions outside the text, not visible spaces.
--- With padding = 2, the center sweeps left to right through these positions:
---   Position: -1 0 | 1 2 3 4 5 | 6 7
---   Text:      . . | H E L L O | . .
--- At -1, H is two positions away: all letters are dim.
--- At  0, H is one position away and begins to brighten.
--- At  1, the center reaches H at full brightness.
--- After O, the center continues right, leaving all text dim before repeating.
local shimmer_edge_padding = #shimmer_opacity - 1

local function setup_highlights()
	local current = assert(state)
	for name, link in pairs {
		Error = 'DiagnosticError',
		Warn = 'DiagnosticWarn',
		Info = 'DiagnosticInfo',
		Hint = 'DiagnosticHint',
	} do
		api.nvim_set_hl(0, 'BetterStatusline' .. name, { link = link })
	end
	local normal = api.nvim_get_hl(0, { name = 'Normal', link = false })
	for _, name in ipairs { 'WinBar', 'WinBarNC' } do
		local base = api.nvim_get_hl(0, { name = name, link = false })
		local fg, bg = base.fg or normal.fg, base.bg or normal.bg
		for level, amount in ipairs(shimmer_opacity) do
			local color = vim.deepcopy(base)
			-- Blend only known RGB colors. With reverse enabled, changing the
			-- foreground would change the displayed background instead of the text.
			if fg and bg and not base.reverse then
				color.fg = blend_rgb(fg, bg, amount)
			end
			api.nvim_set_hl(0, 'BetterStatuslineShimmer' .. name .. level, color)
		end
	end
	local base = api.nvim_get_hl(0, { name = 'StatusLine', link = false })
	for name, source in pairs {
		Tracked = 'Added',
		Untracked = 'DiagnosticWarn',
		Upstream = 'Comment',
		Conflict = 'DiagnosticError',
	} do
		local color = api.nvim_get_hl(0, { name = source, link = false })
		api.nvim_set_hl(0, 'BetterStatuslineGit' .. name, vim.tbl_extend('force', base, { fg = color.fg }))
	end
	for _, family in ipairs(valid_families) do
		local color = current.mode_colors[family]
			or (family == 'select' and current.mode_colors.visual)
			or (family == 'operator' and current.mode_colors.normal)
		if type(color) == 'string' then
			color = api.nvim_get_hl(0, { name = color, link = false, create = false })
		end
		api.nvim_set_hl(0, 'BetterStatuslineMode_' .. family, vim.tbl_extend('force', base, color or {}))
	end
end

local git_indicators = {
	{ 'tracked', '+', 'Tracked' },
	{ 'untracked', '?', 'Untracked' },
	{ 'ahead', '↑', 'Upstream' },
	{ 'behind', '↓', 'Upstream' },
	{ 'conflicts', '↔', 'Conflict' },
}

---@param result? FfiGitStatus
---@return string
local function format_git(result)
	if not result then
		return ''
	end
	local counts = {}
	for _, indicator in ipairs(git_indicators) do
		local field, symbol, group = unpack(indicator)
		if result[field] > 0 then
			counts[#counts + 1] = '%#BetterStatuslineGit' .. group .. '#' .. symbol .. result[field] .. '%*'
		end
	end
	return '󿂠 ' .. escape_text(result.branch) .. (#counts > 0 and separator .. table.concat(counts, ' ') or '')
end

---Return cached Git text without waiting; throttle asynchronous lookups when stale.
---@param dir string
---@return string text Formatted branch and counts; empty until known.
local function cached_git(dir)
	local setup_state = assert(state)
	local entry = setup_state.repositories[dir]
	local now = vim.uv.now()
	if not entry then
		entry = { text = '', last_request_ms = -math.huge }
		setup_state.repositories[dir] = entry
	end
	if not entry.pending and now - entry.last_request_ms > 2000 then
		entry.pending, entry.last_request_ms = true, now
		local queued, err = native_git.status(dir, function(result)
			if state ~= setup_state then
				return
			end
			entry.pending = false
			local text = format_git(result)
			if entry.text ~= text or entry.last_request_ms == -math.huge then
				entry.text = text
				request_refresh()
			end
		end)
		if not queued then
			entry.pending = false
			error(err)
		end
	end
	return entry.text
end

---Format a name at the current shimmer frame without changing its display width.
---@param name string
---@param win integer
---@return string
local function shimmer_name(name, win)
	local chars = vim.fn.split(name, '\\zs')
	local cycle_length = #chars + 2 * shimmer_edge_padding
	local center = (assert(state).frame - 1) % cycle_length + 1 - shimmer_edge_padding
	local group = win == api.nvim_get_current_win() and 'WinBar' or 'WinBarNC'
	local parts = {}
	for i, char in ipairs(chars) do
		local distance = math.abs(i - center)
		local level = math.max(1, #shimmer_opacity - distance)
		parts[#parts + 1] = '%#BetterStatuslineShimmer' .. group .. level .. '#' .. escape_text(char)
	end
	return table.concat(parts) .. '%*'
end

---Format attached client names, animating names with unfinished work.
---@param buf integer
---@param win integer
---@return string text Formatted client names, or empty when none are attached.
local function lsp_names(buf, win)
	local names, busy, seen = {}, {}, {}
	for _, client in ipairs(vim.lsp.get_clients { bufnr = buf }) do
		if not seen[client.name] then
			seen[client.name] = true
			names[#names + 1] = client.name
		end
		local tokens = assert(state).progress_tokens[client.id]
		busy[client.name] = busy[client.name] or (tokens and next(tokens) ~= nil)
	end
	local parts = {}
	for _, name in ipairs(names) do
		parts[#parts + 1] = busy[name] and shimmer_name(name, win) or escape_text(name)
	end
	return #parts > 0 and '‹' .. table.concat(parts, ' ') .. '›' or ''
end

---@param win integer
---@param buf integer
---@return string format Winbar format, or empty for a terminal.
local function build_winbar(win, buf)
	local bo = vim.bo[buf]
	if bo.buftype == 'terminal' or bo.filetype == 'terminal' then
		return ''
	end
	local name = api.nvim_buf_get_name(buf)
	-- Resolve the path inside this window so :lcd in another split cannot change its label.
	local path = name == '' and '- NO NAME -'
		or api.nvim_win_call(win, function()
			return vim.fn.fnamemodify(name, ':~:.')
		end)
	local left = escape_text(path)
		.. (bo.modified and '*' or '')
		.. ((bo.readonly or not bo.modifiable) and ' 󿂢' or '')
	local right, diagnostic_counts = {}, vim.diagnostic.count(buf)
	for severity, item in ipairs { { 'Error', '●' }, { 'Warn', '▲' }, { 'Info', '□' }, { 'Hint', '◊' } } do
		local group, icon = unpack(item)
		local count = diagnostic_counts[severity] or 0
		if count > 0 then
			right[#right + 1] = '%#BetterStatusline' .. group .. '#' .. icon .. ' ' .. count .. '%*'
		end
	end
	local client_names = lsp_names(buf, win)
	if client_names ~= '' then
		right[#right + 1] = client_names
	end
	if bo.filetype ~= '' then
		right[#right + 1] = escape_text(bo.filetype)
	end
	return ' %<' .. left .. '%=' .. table.concat(right, separator) .. ' '
end

---@param tab integer Tabpage handle, not its displayed ordinal number.
---@return string label Unescaped tab label.
local function tab_label(tab)
	local buf = api.nvim_win_get_buf(api.nvim_tabpage_get_win(tab))
	local name, bo = api.nvim_buf_get_name(buf), vim.bo[buf]
	local custom = vim.t[tab].tabname
	if custom and custom ~= '' then
		return custom
	end
	if bo.buftype == 'help' then
		return 'help:' .. vim.fn.fnamemodify(name, ':t:r')
	end
	if bo.buftype == 'terminal' then
		return vim.fn.fnamemodify(vim.o.shell, ':t')
	end
	return name == '' and '[No Name]' or vim.fn.fnamemodify(name, ':t')
end

local function refresh_winbars()
	local winbars = {}
	for _, win in ipairs(api.nvim_list_wins()) do
		local relative = api.nvim_win_get_config(win).relative
		-- Normal windows return an empty string, omitted from the API's enum type.
		---@cast relative string
		if relative == '' then
			local buf = api.nvim_win_get_buf(win)
			winbars[win] = build_winbar(win, buf)
			local expression = winbars[win] == '' and '' or "%!v:lua.require'better_statusline'.winbar()"
			if vim.wo[win].winbar ~= expression then
				vim.wo[win].winbar = expression
			end
		end
	end
	return winbars
end

local function build_tabline()
	local tabs = {}
	for tab_number, tab in ipairs(api.nvim_list_tabpages()) do
		local modified = false
		for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
			modified = modified or vim.bo[api.nvim_win_get_buf(win)].modified
		end
		-- Use tab_number for click targets: Neovim expects the tab's position, not its handle.
		-- Place the truncation point at the active tab to favor its label on narrow screens.
		tabs[#tabs + 1] = (tab == api.nvim_get_current_tabpage() and '%<%#TabLineSel#' or '%#TabLine#')
			.. '%'
			.. tab_number
			.. 'T '
			.. tab_number
			.. (modified and '*' or '')
			.. ' '
			.. escape_text(tab_label(tab))
			.. ' %T'
	end
	return table.concat(tabs) .. '%#TabLineFill#%='
end

local function build_statusline()
	local buf = api.nvim_get_current_buf()
	local name = api.nvim_buf_get_name(buf)
	local dir = vim.bo[buf].buftype == '' and name ~= '' and vim.fn.fnamemodify(name, ':h') or vim.fn.getcwd()
	local git = cached_git(dir)
	local parts = {}
	local mode = api.nvim_get_mode().mode
	parts[1] = '%#'
		.. mode_highlight(mode)
		.. '#'
		.. (mode_labels[mode] or mode_labels[mode:sub(1, 2)] or mode_labels[mode:sub(1, 1)] or mode)
		.. '%*'
	if git ~= '' then
		parts[#parts + 1] = git
	end
	-- Keep %l and %c unevaluated so Neovim updates the cursor position even in a cached string.
	return ' ' .. table.concat(parts, separator) .. '%<%=󿂡 %l, 󿂣 %c '
end

local function rebuild_bars()
	local current = assert(state)
	-- Cache the strings so frequent redraws do not repeat diagnostic, LSP, and Git queries.
	current.winbars = refresh_winbars()
	current.tabline = build_tabline()
	current.statusline = build_statusline()
	vim.cmd.redrawstatus()
	vim.cmd.redrawtabline()
end

---Schedule a refresh, coalescing concurrent requests.
---Does nothing before setup().
request_refresh = function()
	local setup_state = state
	if not setup_state or setup_state.refresh_pending then
		return
	end
	setup_state.refresh_pending = true
	vim.defer_fn(function()
		if state ~= setup_state then
			return
		end
		setup_state.refresh_pending = false
		rebuild_bars()
	end, 40)
end

---Request a display update after changing metadata outside the usual editor events.
---Returns immediately; requests made while an update is pending share that update.
---Does nothing before setup(). Git caches are not invalidated, so this is not a
---forced Git rescan. Ordinary editor events request throttled Git lookups;
---writes, focus gains, and FugitiveChanged bypass that throttle.
---
---Example: >lua
---  vim.t.tabname = 'Review'
---  require('better_statusline').refresh()
---<
---@type fun()
M.refresh = request_refresh

---Install all bars and build the initial display.
---Sets statusline, tabline, and non-floating windows' winbar options, enables a global
---statusline, and shows the tabline only with multiple tabs. Newly opened windows
---are configured automatically.
---These options are owned by this module and may replace another bar configuration.
---
---mode_colors customizes only the mode label. Supported families are normal, insert,
---visual, select, replace, command, terminal, and operator. Values are highlight group
---names or nvim_set_hl attribute tables, inheriting missing attributes from StatusLine.
---Select defaults to visual and operator to normal; other unspecified families and
---missing named groups use StatusLine. Colors follow subsequent colorscheme changes.
---
---Calling setup() again replaces the previous configuration.
---Calling it without options restores default mode colors. Unknown mode families or
---values other than strings/tables raise an error before replacing the existing setup.
---
---Example: >lua
---  require('better_statusline').setup {
---    mode_colors = {
---      insert = { fg = '#0d50c5', bold = true },
---      replace = 'DiagnosticError',
---    },
---  }
---<
---@param opts? {mode_colors?: table<string, string|table>} Optional mode-label colors; defaults to an empty table.
function M.setup(opts)
	opts = opts or {}
	-- Validate mode-family names and value types before replacing the current setup.
	local colors = vim.deepcopy(opts.mode_colors or {})
	assert(type(colors) == 'table', 'mode_colors must be a table')
	for family, color in pairs(colors) do
		assert(vim.list_contains(valid_families, family), 'unknown mode_colors family: ' .. tostring(family))
		assert(type(color) == 'string' or type(color) == 'table', 'mode color must be a highlight name or table')
	end
	if state then
		state.timer:stop()
		state.timer:close()
	end
	local timer = assert(vim.uv.new_timer())
	state = {
		winbars = {},
		repositories = {},
		progress_tokens = {},
		frame = 1,
		mode_colors = colors,
		timer = timer,
	}
	local setup_state = state
	local group = api.nvim_create_augroup('BetterStatusline', { clear = true })
	---@param events vim.api.keyset.events|vim.api.keyset.events[]
	---@param autocmd_opts vim.api.keyset.create_autocmd
	local function on_event(events, autocmd_opts)
		autocmd_opts.group = group
		api.nvim_create_autocmd(events, autocmd_opts)
	end
	setup_highlights()
	vim.o.laststatus, vim.o.showtabline = 3, 1
	vim.o.statusline = "%!v:lua.require'better_statusline'.statusline()"
	vim.o.tabline = "%!v:lua.require'better_statusline'.tabline()"
	-- Text changes refresh modified markers in window bars and tabs.
	on_event({
		'BufEnter',
		'BufWinEnter',
		'WinEnter',
		'WinClosed',
		'TabEnter',
		'TabClosed',
		'BufFilePost',
		'TextChanged',
		'TextChangedI',
		'TextChangedP',
		'FileType',
		'DiagnosticChanged',
		'LspAttach',
		'LspDetach',
		'ModeChanged',
		'DirChanged',
		'TermOpen',
		'VimResized',
	}, { callback = request_refresh })
	local function invalidate_git()
		-- Rescan after saves or external Git operations even inside the throttle.
		for _, entry in pairs(setup_state.repositories) do
			entry.last_request_ms = -math.huge
		end
		request_refresh()
	end
	on_event({ 'BufWritePost', 'FocusGained' }, { callback = invalidate_git })
	on_event('OptionSet', { pattern = { 'modified', 'readonly', 'modifiable', 'buftype' }, callback = request_refresh })
	on_event('User', {
		pattern = 'FugitiveChanged',
		callback = invalidate_git,
	})
	on_event('ColorScheme', {
		callback = function()
			setup_highlights()
			request_refresh()
		end,
	})
	on_event('LspProgress', {
		callback = function(ev)
			local data = ev.data
			local value = data.params.value
			if type(value) ~= 'table' or not value.kind then
				return
			end
			local active_tokens = setup_state.progress_tokens[data.client_id] or {}
			setup_state.progress_tokens[data.client_id] = active_tokens
			active_tokens[data.params.token] = value.kind ~= 'end' and true or nil
			request_refresh()
		end,
	})
	on_event('LspDetach', {
		callback = function(ev)
			-- Detach is buffer-local: retain progress while the client serves other buffers.
			-- Defer the existence check until Neovim has processed the detach.
			vim.schedule(function()
				if state == setup_state and not vim.lsp.get_client_by_id(ev.data.client_id) then
					setup_state.progress_tokens[ev.data.client_id] = nil
				end
			end)
		end,
	})
	setup_state.timer:start(
		1000,
		200,
		vim.schedule_wrap(function()
			if state ~= setup_state then
				return
			end
			local busy = false
			for client_id, active_tokens in pairs(setup_state.progress_tokens) do
				if not vim.lsp.get_client_by_id(client_id) then
					setup_state.progress_tokens[client_id] = nil
				elseif next(active_tokens) then
					busy = true
				end
			end
			if busy then
				setup_state.frame = setup_state.frame + 1
				request_refresh()
			end
		end)
	)
	on_event('VimLeavePre', {
		callback = function()
			setup_state.timer:stop()
			setup_state.timer:close()
		end,
	})
	rebuild_bars()
end

return M
