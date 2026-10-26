-- Better select using Neovim ui2.
local cmdline = require 'vim._core.ui2.cmdline'
local ui2 = require 'vim._core.ui2'
local view_ns = vim.api.nvim_create_namespace '@better_select.view.ns'

---@class better_select.View
---@field search better_select.BetterSelect
---@field win {height: integer}
---@field preview_win? integer
---@field prompt_row integer
---@field prompt_length integer
---@field offset integer
---@field cursor_offset integer
---@field restore function[]

local function close_preview(search)
	local view = search.view
	if view.preview_win then
		pcall(vim.api.nvim_win_close, view.preview_win, true)
		view.preview_win = nil
	end
end

local function update_preview(search)
	local view = search.view
	local entry = search:get_current()
	local ok, preview = true, nil
	if entry and vim.is_callable(search.preview_item) then
		ok, preview = pcall(search.preview_item, entry.v, entry.id, search)
	end
	if not ok then
		search:report_error(preview)
	end
	if not ok or not preview or not preview.buf or not vim.api.nvim_buf_is_valid(preview.buf) then
		close_preview(search)
		return
	end
	local overrides = (vim.is_callable(search.win.preview_opts) and search.win.preview_opts(view)) or {}
	local border = overrides.border or vim.o.winborder
	local options = vim.tbl_extend('force', {
		relative = 'editor',
		focusable = false,
		col = 0,
		width = vim.o.columns,
		height = view.win.height,
		row = vim.o.lines
			- vim.api.nvim_win_get_height(ui2.wins.cmd)
			- view.win.height
			- ((border == '' or border == 'none') and 0 or 2)
			- (search.win.hide_statusline and 0 or 1),
	}, overrides)
	vim.fn.bufload(preview.buf)
	if view.preview_win and vim.api.nvim_win_is_valid(view.preview_win) then
		vim.api.nvim_win_set_buf(view.preview_win, preview.buf)
		vim.api.nvim_win_set_config(view.preview_win, options)
	else
		view.preview_win = vim.api.nvim_open_win(preview.buf, false, options)
	end
	vim.wo[view.preview_win].previewwindow = true
	vim.wo[view.preview_win].eventignorewin = 'all,-FileType'
	vim.wo[view.preview_win].cursorline = preview.pos ~= nil
		and (preview.pos_end == nil or preview.pos_end[1] == preview.pos[1])
	if preview.pos then
		vim.api.nvim_win_set_cursor(view.preview_win, preview.pos)
	end
end

local function set_command_area(rows, height, hidden)
	-- ui2 must retain the user's cmdheight while the picker borrows its window.
	vim._with({ noautocmd = true, o = { splitkeep = 'screen' } }, function()
		vim.api.nvim_win_set_config(ui2.wins.cmd, { height = math.max(1, rows), hide = hidden })
		vim.o.cmdheight = height
	end)
	ui2.msg.set_pos()
end

local function position_prompt_cursor(search, offset)
	local view = search.view
	if offset == nil then
		local cursor = vim.api.nvim_win_get_cursor(ui2.wins.cmd)
		offset = cursor[1] == view.prompt_row + 1 and cursor[2] - view.prompt_length or -1
	end
	if offset < 0 then
		offset = view.cursor_offset
	end
	local line = vim.api.nvim_buf_get_lines(search.buf, view.prompt_row, view.prompt_row + 1, false)[1] or ''
	view.cursor_offset = math.min(math.max(0, offset), math.max(0, #line - view.prompt_length))
	vim._with({ noautocmd = true }, function()
		vim.api.nvim_win_set_cursor(ui2.wins.cmd, { view.prompt_row + 1, view.prompt_length + view.cursor_offset })
	end)
end

local function add_highlight(search, row, col, group, options)
	options = options or {}
	options.hl_group, options.hl_mode = group, 'combine'
	local ok, err = pcall(vim.api.nvim_buf_set_extmark, search.buf, view_ns, row, col, options)
	if not ok then
		search:report_error(err)
	end
end

local function highlight_match(search, index, row)
	local match = search.matches[index]
	local entry = search.items[match[1]]
	local indent = vim.fn.strdisplaywidth(search.opts.pointer) + 1
	local text_col = indent + (entry.icon and #entry.icon + 2 or 0)
	if index == search.idx then
		add_highlight(search, row, 0, 'BetterSelectSel', {
			hl_eol = true,
			end_row = row + 1,
			end_col = 0,
			priority = 10,
			virt_text = { { search.opts.pointer, 'BetterSelectPointer' } },
			virt_text_pos = 'overlay',
		})
	end
	if search.marked[entry.id] then
		add_highlight(search, row, 0, 'BetterSelectMarkLine', {
			hl_eol = true,
			end_row = row + 1,
			end_col = 0,
			priority = 20,
		})
		add_highlight(search, row, indent - 1, nil, {
			virt_text = { { search.opts.marker, 'BetterSelectMark' } },
			virt_text_pos = 'overlay',
			priority = 20,
		})
	end
	if entry.icon and entry.icon_hl then
		add_highlight(search, row, indent, entry.icon_hl, { end_col = text_col, priority = 40 })
	end
	for _, highlight in ipairs(entry.hls or {}) do
		add_highlight(search, row, text_col + highlight[1][1], highlight[2], {
			end_col = text_col + highlight[1][2],
			priority = 30,
		})
	end
	for _, character in ipairs(match[2] or {}) do
		local first = vim.fn.byteidx(entry.text, character)
		local last = vim.fn.byteidx(entry.text, character + 1)
		add_highlight(
			search,
			row,
			text_col + first,
			index == search.idx and 'BetterSelectMatchSel' or 'BetterSelectMatch',
			{
				end_col = text_col + (last < 0 and #entry.text or last),
				priority = 50,
			}
		)
	end
end

local function render(search)
	local view = search.view
	search:clamp_selection()
	local requested = search.win.height <= 1 and vim.o.lines * search.win.height or search.win.height
	view.win.height = math.max(2, math.min(math.ceil(requested), vim.o.lines - 2))
	local capacity = view.win.height - 1
	local first = math.max(1, math.min(view.offset + 1, math.max(1, #search.matches - capacity + 1)))
	if search.idx == 0 then
		first = 1
	elseif search.idx < first then
		first = search.idx
	elseif search.idx >= first + capacity then
		first = search.idx - capacity + 1
	end
	view.offset = first - 1
	local count = math.min(capacity, #search.matches)
	local list_height = search.opts.shrink and count or capacity
	view.prompt_row = search.opts.bottom and list_height or 0
	local list_row = search.opts.bottom and 0 or 1
	local prefix = vim.fn.strtrans(search.prompt_text .. ' ')
	view.prompt_length = #prefix
	local lines = {}
	for _ = 1, list_height + 1 do
		lines[#lines + 1] = ''
	end
	lines[view.prompt_row + 1] = prefix .. vim.fn.strtrans(search.query)
	for index = first, first + count - 1 do
		local entry = search.items[search.matches[index][1]]
		if not (entry.icon and entry.icon_hl) and vim.is_callable(search.get_icon) then
			entry.icon, entry.icon_hl = search.get_icon(entry)
		end
		if not entry.hls and vim.is_callable(search.hl_item) then
			entry.hls = search.hl_item(entry)
		end
		lines[list_row + index - first + 1] = (' '):rep(vim.fn.strdisplaywidth(search.opts.pointer) + 1)
			.. (entry.icon and entry.icon .. '  ' or '')
			.. entry.text
	end

	if cmdline.highlighter and cmdline.highlighter.active then
		cmdline.highlighter.active[search.buf] = nil
	end
	if ui2.msg.cmd.msg_row ~= -1 then
		ui2.msg.msg_clear()
	end
	ui2.msg.virt.last = { {}, {}, {}, {} }
	-- Resize before writing so the prompt cannot scroll out of the command area.
	set_command_area(#lines, search.win.hide_statusline and 0 or #lines, false)
	vim.api.nvim_buf_clear_namespace(search.buf, view_ns, 0, -1)
	if vim.fn.prompt_getprompt(search.buf) ~= prefix then
		vim.fn.prompt_setprompt(search.buf, prefix)
	end
	vim.api.nvim_buf_set_lines(search.buf, 0, -1, false, lines)
	cmdline.srow, cmdline.erow, cmdline.level = 0, #lines, 1
	vim.api.nvim_buf_set_mark(search.buf, ':', view.prompt_row + 1, #prefix, {})
	position_prompt_cursor(search, view.cursor_offset)
	add_highlight(search, view.prompt_row, 0, 'BetterSelectPrompt', { end_col = #prefix })
	local info = { index = ('[%d]'):format(search.idx), list = ('(%d/%d)'):format(#search.matches, #search.items) }
	local labels = vim.tbl_map(function(name)
		return info[name] or ''
	end, search.opts.info_list)
	add_highlight(search, view.prompt_row, 0, nil, {
		virt_text = { { table.concat(labels, ' '), 'BetterSelectInfo' } },
		virt_text_pos = 'eol_right_align',
	})
	for index = first, first + count - 1 do
		highlight_match(search, index, list_row + index - first)
	end
	if view.preview_win then
		update_preview(search)
	end
end

local function use_options(view, target, values)
	for name, value in pairs(values) do
		local saved = vim.api.nvim_get_option_value(name, target)
		view.restore[#view.restore + 1] = function()
			vim.api.nvim_set_option_value(name, saved, target)
		end
		vim.api.nvim_set_option_value(name, value, target)
	end
end

local function open_dialog(search)
	local view = search.view
	view.previous_win = vim.api.nvim_get_current_win()
	view.previous_buf = vim.api.nvim_get_current_buf()
	view.previous_view = vim.fn.winsaveview()
	view.previous_prompt = vim.fn.prompt_getprompt(search.buf)
	view.previous_height = vim.o.cmdheight
	view.previous_config = vim.api.nvim_win_get_config(ui2.wins.cmd)
	view.augroup = vim.api.nvim_create_augroup('better_select.dialog', { clear = true })
	vim._with({ noautocmd = true }, function()
		use_options(view, { win = ui2.wins.cmd, scope = 'local' }, {
			eventignorewin = 'all,-FileType,-InsertCharPre,-TextChangedI,-CursorMovedI,-InsertLeave,-BufLeave,-WinLeave',
			winhighlight = 'Normal:BetterSelectNormal,Search:,CurSearch:,IncSearch:',
			wrap = false,
			signcolumn = 'no',
		})
		use_options(
			view,
			{ buf = search.buf },
			{ buftype = 'prompt', autocomplete = false, filetype = 'better-select' }
		)
		use_options(view, { scope = 'global' }, { showmode = false, showcmd = false })
		cmdline.prompt = false
		render(search)
		vim.api.nvim_set_current_win(ui2.wins.cmd)
		vim.cmd.startinsert { bang = true }
	end)
	local function watch(events, options, callback)
		vim.api.nvim_create_autocmd(
			events,
			vim.tbl_extend('force', options, { group = view.augroup, callback = callback })
		)
	end
	watch('TextChangedI', { buffer = search.buf }, function()
		local line = vim.api.nvim_buf_get_lines(search.buf, view.prompt_row, view.prompt_row + 1, false)[1] or ''
		local query = line:sub(view.prompt_length + 1)
		if query ~= search.query then
			position_prompt_cursor(search)
			search:set_query(query)
		end
	end)
	watch('CursorMovedI', { buffer = search.buf }, function()
		position_prompt_cursor(search)
	end)
	watch('VimResized', {}, function()
		render(search)
	end)
	watch('ModeChanged', { pattern = 'i:*' }, function()
		search:cancel()
	end)
	watch({ 'InsertLeave', 'BufLeave', 'WinLeave' }, { buffer = search.buf }, function()
		search:cancel()
	end)
end

local function close_dialog(search)
	local view = search.view
	if view.augroup then
		vim.api.nvim_del_augroup_by_id(view.augroup)
	end
	close_preview(search)
	vim._with({ noautocmd = true }, function()
		vim.cmd.stopinsert()
		vim.api.nvim_buf_clear_namespace(search.buf, view_ns, 0, -1)
		vim.api.nvim_buf_set_lines(search.buf, 0, -1, false, {})
		vim.fn.prompt_setprompt(search.buf, view.previous_prompt or '')
		for index = #view.restore, 1, -1 do
			pcall(view.restore[index])
		end
		cmdline.srow, cmdline.erow, cmdline.level, cmdline.prompt = 0, 0, 0, false
		if view.previous_height then
			set_command_area(view.previous_config.height, view.previous_height, view.previous_config.hide)
		end
		if view.previous_win and vim.api.nvim_win_is_valid(view.previous_win) then
			vim.api.nvim_set_current_win(view.previous_win)
			vim.fn.winrestview(view.previous_view)
		end
	end)
	-- stopinsert completes after this callback and can move the restored cursor left.
	vim.schedule(function()
		if
			vim.api.nvim_get_current_win() == view.previous_win
			and vim.api.nvim_get_current_buf() == view.previous_buf
		then
			vim.fn.winrestview(view.previous_view)
		end
	end)
end

local M = {}
---@class better_select.BetterSelect: better_select.Options
---@field items better_select.Entry[]
---@field matches table[] Ordered {source_index, zero_based_character_positions, score} matches
---@field idx integer 1-based match position; 0 means no selection
---@field query string Current search text, shared by local and live modes
---@field closed boolean
---@field view better_select.View
local BetterSelect = {}
BetterSelect.__index = BetterSelect
local active

function M.current()
	return active
end
local defaults = {
	opts = {
		preselect = true,
		bottom = true,
		shrink = true,
		prompt_prefix = '›',
		prompt_title = true,
		pointer = '»',
		marker = '│',
		info_list = { 'list' },
	},
	win = { height = 0.4, hide_statusline = false },
}
local config = {}

---@alias better_select.Highlight {[1]: {[1]: integer, [2]: integer}, [2]: string} Byte range {start, end_exclusive} and highlight group

---@class better_select.Entry
---@field id integer 1-based original source index
---@field v any Original source value (never copied)
---@field text string Single-line display and search text
---@field icon? string
---@field icon_hl? string
---@field hls? better_select.Highlight[] Byte ranges relative to the formatted label

---@class better_select.Options
---@field source table|fun(query: string, emit: fun(items: table?, err?: any), ctx: table): table|function|nil
---@field format_item? fun(item: any, index: integer): string
---@field on_choice? fun(item: any, index: integer, marked: table, search: table)
---@field on_open? fun(search: table) Configure picker-local bindings after opening
---@field on_cancel? fun(search: table)
---@field preview_item? fun(item: any, index: integer, search: table): table? {buf, pos?, pos_end?}
---@field get_icon? fun(entry: better_select.Entry): string?, string?
---@field hl_item? fun(entry: better_select.Entry): table[]?
---@field to_quickfix? fun(item: any, index: integer): table
---@field sorter? fun(entries: better_select.Entry[], query: string): table[] {index, character_positions, score}
---@field actions? table<string, fun(search: table)>
---@field prompt? string
---@field default_text? string
---@field live? boolean Default: true for providers, false for lists
---@field debounce? integer Provider delay in milliseconds (default 30)
---@field opts? table Prompt, selection, marking, and match-count display options
---@field win? table BetterSelect height, statusline visibility, and preview-window options

function M.setup(opts)
	config = vim.deepcopy(opts or {})
end

-- matchfuzzypos returns character offsets; the view converts them to byte ranges.
function M.sorter(entries, query)
	local items = vim.iter(entries)
	local pattern = query:match '^/([^/]*)/'
	if pattern then
		items:filter(function(entry)
			return entry.text:match(pattern) ~= nil
		end)
		query = query:gsub('^/[^/]*/', '')
	end
	if query == '' then
		return items
			:map(function(entry)
				return { entry.id, {}, 0 }
			end)
			:totable()
	end
	local result = vim.fn.matchfuzzypos(items:totable(), query, { key = 'text' })
	return vim.iter(ipairs(result[1]))
		:map(function(i, entry)
			return { entry.id, result[2][i], result[3][i] }
		end)
		:totable()
end

function BetterSelect:report_error(err)
	vim.schedule(function()
		vim.notify('better_select: ' .. tostring(err), vim.log.levels.ERROR)
	end)
end

function BetterSelect:clamp_selection()
	self.idx = math.min(#self.matches, math.max(self.opts.preselect and 1 or 0, self.idx))
end

function BetterSelect:get_current(index)
	index = index or (self.matches[self.idx] and self.matches[self.idx][1])
	return index and self.items[index] or nil
end

-- Marked values stay in source order, including values hidden by fuzzy filtering.
function BetterSelect:get_marked()
	return vim.iter(self.items)
		:filter(function(entry)
			return self.marked[entry.id]
		end)
		:map(function(entry)
			return entry.v
		end)
		:totable()
end

function BetterSelect:update_matches()
	if self.closed then
		return
	end
	local ok, matches = pcall(self.live and function(entries)
		return vim.tbl_map(function(entry)
			return { entry.id, {}, 0 }
		end, entries)
	end or self.sorter, self.items, self.query)
	if not ok then
		self:report_error(matches)
		return
	end
	self.matches = matches
	self:clamp_selection()
	if self.view then
		render(self)
	end
end

function BetterSelect:replace_items(items)
	assert(type(items) == 'table' and vim.islist(items), 'source must produce a list')
	local entries = {}
	for index, value in ipairs(items) do
		local text = self.format_item and self.format_item(value, index) or tostring(value)
		assert(type(text) == 'string', 'format_item must return a string')
		entries[index] = { id = index, v = value, text = vim.fn.strtrans(text) }
	end
	self.items, self.marked, self.idx = entries, {}, 0
	self:update_matches()
end

function BetterSelect:cancel_pending_request()
	self.generation = self.generation + 1
	if self.pending_cancel then
		local cancel = self.pending_cancel
		self.pending_cancel = nil
		local ok, err = pcall(cancel)
		if not ok then
			self:report_error(err)
		end
	end
end

function BetterSelect:refresh(immediate)
	if self.closed then
		return
	end
	self:cancel_pending_request()
	local generation = self.generation
	local query = self.live and self.query or ''
	local function current()
		return not self.closed and self.generation == generation
	end
	local function emit(items, err)
		vim.schedule(function()
			if not current() then
				return
			end
			if err then
				self:report_error(err)
				return
			end
			local ok, result = pcall(self.replace_items, self, items)
			if not ok then
				self:report_error(result)
			end
		end)
	end
	local function request()
		if not current() then
			return
		end
		local ok, result = pcall(self.source, query, emit, {
			search = self,
			cancelled = function()
				return not current()
			end,
		})
		if not ok then
			emit(nil, result)
		elseif type(result) == 'table' then
			emit(result)
		elseif type(result) == 'function' then
			if current() then
				self.pending_cancel = result
			else
				pcall(result)
			end
		elseif result ~= nil then
			emit(nil, 'provider must return a list, cancellation function, or nil')
		end
	end
	-- Delay source requests without delaying invalidation of older results.
	if immediate or self.debounce == 0 then
		request()
	else
		vim.defer_fn(request, self.debounce)
	end
end

function BetterSelect:set_query(query)
	assert(type(query) == 'string', 'query must be a string')
	if self.closed then
		return
	end
	self.idx, self.query = 0, query
	if self.live then
		self.items, self.matches, self.marked = {}, {}, {}
		self:refresh()
		render(self)
	else
		self:update_matches()
	end
end

function BetterSelect:toggle_live()
	if type(self.source) ~= 'function' then
		return
	end
	self.live = not self.live
	self.idx = 0
	if self.live then
		self:refresh(true)
		render(self)
	else
		self:cancel_pending_request()
		self:update_matches()
	end
end

function BetterSelect:close()
	if self.closed then
		return
	end
	self.closed = true
	self:cancel_pending_request()
	if self.view then
		for _, key in ipairs(self.keys) do
			pcall(vim.keymap.del, 'i', key, { buffer = self.buf })
		end
		close_dialog(self)
	end
	if active == self then
		active = nil
	end
end

function BetterSelect:cancel()
	if self.closed then
		return
	end
	self:close()
	if self.on_cancel then
		vim.schedule(function()
			self.on_cancel(self)
		end)
	end
end

function BetterSelect:accept()
	if self.closed then
		return
	end
	-- TextChangedI can lag behind Enter when pasted/fast input arrives in one batch.
	local line = vim.api.nvim_buf_get_lines(self.buf, self.view.prompt_row, self.view.prompt_row + 1, false)[1] or ''
	local query = line:sub(self.view.prompt_length + 1)
	if query ~= self.query then
		self:set_query(query)
		if self.live then
			return
		end -- Wait for results for the new query before accepting.
	end
	local entry = self:get_current()
	if not entry then
		return
	end
	local marked = self:get_marked()
	self:close()
	if self.on_choice then
		vim.schedule(function()
			self.on_choice(entry.v, entry.id, marked, self)
		end)
	end
end

function BetterSelect:set_quickfix()
	if not self.to_quickfix then
		return
	end
	local has_marks = next(self.marked) ~= nil
	local selected

	if has_marks then
		selected = vim.iter(self.items):filter(function(entry)
			return self.marked[entry.id]
		end)
	else
		selected = vim.iter(self.matches):map(function(match)
			return self.items[match[1]]
		end)
	end

	local entries = selected
		:map(function(entry)
			return self.to_quickfix(entry.v, entry.id)
		end)
		:totable()
	self:close()
	vim.schedule(function()
		vim.fn.setqflist({}, ' ', { title = self.prompt, items = entries })
		vim.cmd.copen()
	end)
end

function BetterSelect:action(name)
	if self.closed then
		return
	end
	local ok, err = pcall(function()
		if self.actions[name] then
			self.actions[name](self)
		elseif name == 'down' or name == 'up' then
			self.idx = self.idx + (name == 'down' and 1 or -1)
			self:clamp_selection()
			render(self)
		elseif name == 'mark' then
			local entry = self:get_current()
			if entry then
				self.marked[entry.id] = not self.marked[entry.id] or nil
				render(self)
			end
		elseif name == 'toggle_preview' then
			if self.view.preview_win then
				close_preview(self)
			else
				update_preview(self)
			end
		elseif name == 'accept' or name == 'cancel' or name == 'toggle_live' or name == 'set_quickfix' then
			self[name](self)
		end
	end)
	if not ok then
		self:report_error(err)
	end
end

local function define_highlights()
	local groups = {
		BetterSelectNormal = { link = 'Pmenu' },
		BetterSelectPrompt = { link = 'Question' },
		BetterSelectSel = { link = 'PmenuSel' },
		BetterSelectPointer = { link = 'PmenuSel' },
		BetterSelectMatch = { link = 'PmenuMatch' },
		BetterSelectMatchSel = { link = 'PmenuMatchSel' },
		BetterSelectInfo = { link = 'PmenuExtra' },
		BetterSelectMark = { link = 'Special' },
		BetterSelectMarkLine = { link = 'Visual' },
	}
	for name, spec in pairs(groups) do
		spec.default = true
		vim.api.nvim_set_hl(0, name, spec)
	end
end

local highlights_initialized = false

local function initialize_highlights()
	if highlights_initialized then
		return
	end

	define_highlights()
	vim.api.nvim_create_autocmd('ColorScheme', {
		group = vim.api.nvim_create_augroup('better_select.highlights', { clear = true }),
		callback = define_highlights,
	})
	highlights_initialized = true
end

---@param options better_select.Options
---@return table search Handle: set_query, refresh, get_current, get_marked, action, accept, cancel
function M.open(options)
	assert(type(options) == 'table', 'open expects an options table')
	assert(
		type(options.source) == 'function' or (type(options.source) == 'table' and vim.islist(options.source)),
		'source must be a list or provider function'
	)
	assert(vim.fn.has 'nvim-0.12' == 1, 'search requires Neovim >= 0.12 with ui2 enabled')
	assert(ui2.msg and ui2.cfg.enable, "enable require('vim._core.ui2').enable({}) before opening a search")
	local overrides = vim.tbl_extend('force', {}, options)
	overrides.source = nil
	local opts = vim.tbl_deep_extend('force', defaults, config, overrides)
	-- Deep merging opaque source values would destroy identity and metatables.
	opts.source = options.source
	opts.live = options.live
	if opts.live == nil then
		opts.live = type(opts.source) == 'function'
	end
	opts.live = opts.live and type(opts.source) == 'function'
	opts.items, opts.matches, opts.marked = {}, {}, {}
	opts.idx, opts.generation, opts.closed = 0, 0, false
	opts.actions = opts.actions or {}
	opts.sorter = opts.sorter or M.sorter
	opts.debounce = opts.debounce or 30
	assert(type(opts.debounce) == 'number' and opts.debounce >= 0, 'debounce must be nonnegative')
	assert(type(opts.win.height) == 'number' and opts.win.height > 0, 'win.height must be positive')
	opts.prompt = opts.prompt or ''
	opts.prompt_text = opts.opts.prompt_title and (opts.prompt .. ' ' .. opts.opts.prompt_prefix)
		or opts.opts.prompt_prefix
	opts.query = opts.default_text or ''
	local self = setmetatable(opts, BetterSelect)
	if type(self.source) == 'table' then
		self:replace_items(self.source)
	end
	if active then
		active:cancel()
	end
	active = self
	ui2.check_targets()
	initialize_highlights()
	self.buf = ui2.bufs.cmd
	self.keys = {}
	self.view = {
		search = self,
		win = {},
		restore = {},
		offset = 0,
		prompt_row = 0,
		prompt_length = 0,
		cursor_offset = #vim.fn.strtrans(self.query),
	}
	local ok, err = pcall(function()
		open_dialog(self)
		local actions = {
			'down',
			'up',
			'accept',
			'cancel',
			'mark',
			'toggle_live',
			'toggle_preview',
			'set_quickfix',
			'split',
			'vsplit',
			'tabnew',
		}
		for name in pairs(self.actions) do
			if not vim.list_contains(actions, name) then
				actions[#actions + 1] = name
			end
		end
		for _, action in ipairs(actions) do
			local plug = '<Plug>(acme-better-select-' .. action:gsub('_', '-') .. ')'
			vim.keymap.set('i', plug, function()
				self:action(action)
			end, { buffer = self.buf, nowait = true, unique = true })
			self.keys[#self.keys + 1] = plug
		end
		if self.on_open then
			self.on_open(self)
		end
	end)
	if not ok then
		self:close()
		error(err)
	end
	if type(self.source) == 'function' then
		self:refresh(true)
	end
	return self
end

---@generic T
---@param items T[]
---@param opts table
---@param on_choice fun(item: T?, index: integer?)
function M.select(items, opts, on_choice)
	local options = vim.tbl_extend('force', opts or {}, {
		source = items,
		on_choice = function(item, index)
			on_choice(item, index)
		end,
		on_cancel = function()
			on_choice(nil, nil)
		end,
	})
	return M.open(options)
end

return M
