-- Better select using Neovim ui2.
-- Renderer adapted from comfysage/artio.nvim, revision ebf5ed35bf17babeee20b04129ce60a382214687.
-- Modified 2026-10-06: generic sources, synchronous cleanup, and UTF-8 highlights.
-- Modified 2026-10-24: consolidated module and simplified rendering.
-- Licensed under EUPL-1.2; see better_select/LICENSE and better_select/NOTICE.
local cmdline = require 'vim._core.ui2.cmdline'
local ui2 = require 'vim._core.ui2'

local view_ns = vim.api.nvim_create_namespace '@better_select.view.ns'
local prompt_hl_id

---@class better_select.View
---@field search better_select.BetterSelect
---@field closed boolean
---@field opts table<'win'|'buf'|'g',table<string,any>>
---@field win better_select.View.win
---@field preview_win integer
local View = {}
View.__index = View

---@param search better_select.BetterSelect
function View:new(search)
	return setmetatable({
		search = search,
		closed = false,
		opts = {},
		prompt_length = 0,
		prompt_row = 0,
		max_list_height = 1,
		start_row = 0,
		offset = 0,
		win = {
			height = 1,
		},
	}, View)
end

---@class better_select.View.win
---@field height integer

function View:draw_prompt_text()
	local lines = {}
	for line in (self.search.prompt_text .. (' '):rep(cmdline.indent) .. '\n'):gmatch '(.-)\n' do
		lines[#lines + 1] = vim.fn.strtrans(line)
	end
	local prompt = lines[#lines]
	self.prompt_length = #prompt
	lines[#lines] = prompt .. vim.fn.strtrans(self.search.query)
	self:update_prompt_position()
	self:set_lines(self.prompt_row, self.prompt_row + 1, lines)
	if vim.fn.prompt_getprompt(ui2.bufs.cmd) ~= prompt then
		vim.fn.prompt_setprompt(ui2.bufs.cmd, prompt)
	end
	pcall(vim.api.nvim_buf_set_mark, ui2.bufs.cmd, ':', self.prompt_row + 1, self.prompt_length, {})
end

--- Set the 'cmd_height' and cmdline window height. Reposition message windows.
---
---@param win integer Cmdline window in the current tabpage.
---@param hidden boolean Whether to hide the window.
---@param height integer (Text)height of the cmdline window.
function View:configure_window(win, hidden, height)
	if ui2.cmdheight == 0 and vim.api.nvim_win_get_config(win).hide ~= hidden then
		vim.api.nvim_win_set_config(win, { hide = hidden, height = not hidden and height or nil })
	elseif vim.api.nvim_win_get_height(win) ~= height then
		vim.api.nvim_win_set_height(win, height)
	end

	if not hidden and self.search.win.hide_statusline then
		height = 0
	end

	if vim.o.cmdheight ~= height then
		-- Preserve the editor view and prevent ui2's OptionSet handler from
		-- replacing its saved cmd_height with the search's temporary height.
		vim._with({ noautocmd = true, o = { splitkeep = 'screen' } }, function()
			vim.o.cmdheight = height
		end)
		ui2.msg.set_pos()
	end

	if self.preview_win and vim.api.nvim_win_is_valid(self.preview_win) then
		vim.api.nvim_win_set_config(self.preview_win, self:get_preview_window_options())
	end
end

---@param predicted? integer The predicted height of the cmdline window
function View:update_window_height(predicted)
	local height = math.max(1, predicted or vim.api.nvim_win_text_height(ui2.wins.cmd, {}).all)
	height = math.min(height, self.win.height)
	self:configure_window(ui2.wins.cmd, false, height)
end

function View:save_editor_view()
	self.save = vim.fn.winsaveview()
	self.previous_win = vim.api.nvim_get_current_win()
end

function View:restore_editor_view()
	vim.api.nvim_set_current_win(self.previous_win)
	vim.fn.winrestview(self.save)
end

---@param restore? boolean
function View:configure_editor_options(restore)
	local opts = {
		win = {
			eventignorewin = 'all,-FileType,-InsertCharPre,-TextChangedI,-CursorMovedI,-InsertLeave,-BufLeave,-WinLeave',
			winhighlight = 'Normal:BetterSelectNormal,Search:,CurSearch:,IncSearch:',
			signcolumn = 'no',
			wrap = false,
		},
		buf = {
			filetype = 'better-select',
			buftype = 'prompt',
			autocomplete = false,
		},
		g = {
			showmode = false,
			showcmd = false,
		},
	}

	for level, o in pairs(opts) do
		self.opts[level] = self.opts[level] or {}
		local props = {
			scope = level == 'g' and 'global' or 'local',
			buf = level == 'buf' and ui2.bufs.cmd or nil,
			win = level == 'win' and ui2.wins.cmd or nil,
		}

		for name, value in pairs(o) do
			if restore then
				if self.opts[level][name] ~= nil then
					vim.api.nvim_set_option_value(name, self.opts[level][name], props)
				end
			else
				self.opts[level][name] = vim.api.nvim_get_option_value(name, props)
				vim.api.nvim_set_option_value(name, value, props)
			end
		end
	end
end

function View:update_layout()
	if self.search.win.height > 1 then
		self.win.height = self.search.win.height
	else
		self.win.height = vim.o.lines * self.search.win.height
	end
	self.win.height = math.min(math.max(math.ceil(self.win.height), 2), math.max(2, vim.o.lines - 2))

	self.max_list_height = math.max(self.win.height - 1, 1)
end

function View:open()
	self.augroup = vim.api.nvim_create_augroup('@better_select.view', { clear = true })
	self:save_editor_view()
	self.saved_prompt = vim.fn.prompt_getprompt(ui2.bufs.cmd)
	self:update_layout()
	cmdline.prompt, cmdline.srow, cmdline.indent, cmdline.level = false, 0, 1, 1
	self:redraw()
	vim._with({ noautocmd = true }, function()
		vim.api.nvim_set_current_win(ui2.wins.cmd)
	end)
	self:configure_editor_options()
	self:position_prompt_cursor(#vim.fn.strtrans(self.search.query))
	vim._with({ noautocmd = true }, function()
		vim.cmd.startinsert { bang = true }
	end)
	vim.api.nvim_create_autocmd('TextChangedI', {
		group = self.augroup,
		buffer = ui2.bufs.cmd,
		callback = function()
			self:read_prompt_query()
		end,
	})
	vim.api.nvim_create_autocmd('CursorMovedI', {
		group = self.augroup,
		buffer = ui2.bufs.cmd,
		callback = function()
			self:position_prompt_cursor()
		end,
	})
	vim.api.nvim_create_autocmd('VimResized', {
		group = self.augroup,
		callback = function()
			self:update_layout()
			self:redraw()
		end,
	})
	vim.api.nvim_create_autocmd('ModeChanged', {
		group = self.augroup,
		pattern = 'i:*',
		callback = function()
			self.search:cancel()
		end,
	})
	vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufLeave', 'WinLeave' }, {
		group = self.augroup,
		buffer = ui2.bufs.cmd,
		callback = function()
			self.search:cancel()
		end,
	})
end

function View:close()
	if self.closed then
		return
	end
	self.closed = true
	pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
	self:close_preview()
	vim.cmd.stopinsert()
	vim.fn.prompt_setprompt(ui2.bufs.cmd, self.saved_prompt or '')
	self:configure_editor_options(true)
	self:clear_rendered_lines()
	cmdline.srow, cmdline.erow = 0, 0
	self:hide_command_window()
	if vim.api.nvim_win_is_valid(self.previous_win) then
		self:restore_editor_view()
	end
end

function View:hide_command_window()
	vim.fn.clearmatches(ui2.wins.cmd) -- Clear matchparen highlights.
	vim.api.nvim_win_set_cursor(ui2.wins.cmd, { 1, 0 })
	vim.api.nvim_buf_set_lines(ui2.bufs.cmd, 0, -1, false, {})

	cmdline.prompt, cmdline.level = false, 0
	self:configure_window(ui2.wins.cmd, true, ui2.cmdheight)
end

function View:redraw()
	if cmdline.highlighter and cmdline.highlighter.active then
		cmdline.highlighter.active[ui2.bufs.cmd] = nil
	end
	if ui2.msg.cmd.msg_row ~= -1 then
		ui2.msg.msg_clear()
	end
	ui2.msg.virt.last = { {}, {}, {}, {} }
	self:clear_rendered_lines()
	self:draw_matches()
	self:draw_prompt_text()
	self:position_prompt_cursor()
	self:update_window_height()
	self:draw_prompt()
	self:highlight_selection()
end

function View:read_prompt_query()
	if self.closed then
		return
	end
	local text = vim.api.nvim_buf_get_lines(ui2.bufs.cmd, self.prompt_row, self.prompt_row + 1, false)[1] or ''
	text = text:sub(self.prompt_length + 1)
	if text ~= self.search.query then
		self.search:set_query(text)
	end
end

---@param pos? integer Zero-based query byte offset; nil or negative preserves the cursor position
function View:position_prompt_cursor(pos)
	self.cursor_pos = self.cursor_pos or { 0, 0 }

	self:update_prompt_position()

	if not pos or pos < 0 then
		local cursor_pos = vim.api.nvim_win_get_cursor(ui2.wins.cmd)
		pos = cursor_pos[2] - self.prompt_length
	end

	-- Keep the cursor out of the noneditable prompt prefix.
	self.cursor_pos[2] = math.max(self.cursor_pos[2], self.prompt_length)

	if self.cursor_pos[1] == self.prompt_row + 1 and self.cursor_pos[2] == self.prompt_length + pos then
		return
	end

	if pos < 0 then
		-- Reuse the last query position when the cursor enters the prompt prefix.
		pos = self.cursor_pos[2] - self.prompt_length
	end

	self.cursor_pos[1], self.cursor_pos[2] = self.prompt_row + 1, self.prompt_length + pos

	vim._with({ noautocmd = true }, function()
		local ok, _ = pcall(vim.api.nvim_win_set_cursor, ui2.wins.cmd, self.cursor_pos)
		if not ok then
			self.search:report_error(('Failed to set cursor %d:%d'):format(self.cursor_pos[1], self.cursor_pos[2]))
		end
	end)
end

function View:clear_rendered_lines()
	self.start_row = self.search.opts.bottom and 0 or 1
	cmdline.erow = self.start_row
	vim.api.nvim_buf_clear_namespace(ui2.bufs.cmd, view_ns, 0, -1)
	self:set_lines(0, -1, {})
end

function View:update_prompt_position()
	self.prompt_row = self.search.opts.bottom and cmdline.erow or 0
end

function View:set_lines(start_pos, end_pos, lines)
	-- Grow the window before adding rows so the prompt stays visible.
	local diff = #lines - (end_pos - start_pos)
	if diff ~= 0 then
		local height = vim.api.nvim_win_text_height(ui2.wins.cmd, {}).all
		local predicted = height + diff
		self:update_window_height(predicted)
	end

	vim.api.nvim_buf_set_lines(ui2.bufs.cmd, start_pos, end_pos, false, lines)
end

local ext_priority = {
	prompt = 1,
	info = 2,
	select = 4,
	marker = 8,
	hl = 16,
	icon = 32,
	match = 64,
}

---@param row integer Zero-based buffer row
---@param col integer Zero-based byte column
---@param opts vim.api.keyset.set_extmark
function View:add_highlight(row, col, opts)
	opts.hl_mode = 'combine'
	opts.invalidate = true
	local ok, err = pcall(vim.api.nvim_buf_set_extmark, ui2.bufs.cmd, view_ns, row, col, opts)
	if not ok then
		self.search:report_error(('Failed to add extmark %d:%d\n\t%s'):format(row, col, err))
	end
end

---@param p better_select.BetterSelect
---@param info 'index'|'list'|string
---@return string
local function format_prompt_info(p, info)
	if info == 'index' then
		return ('[%d]'):format(p.idx)
	elseif info == 'list' then
		return ('(%d/%d)'):format(#p.matches, p.items and #p.items or 0)
	end
	return ''
end

function View:draw_prompt()
	self:update_prompt_position()
	if self.prompt_length > 0 and prompt_hl_id > 0 then
		self:add_highlight(
			self.prompt_row,
			0,
			{ hl_group = prompt_hl_id, end_col = self.prompt_length, priority = ext_priority.prompt }
		)
		self:add_highlight(self.prompt_row, 0, {
			virt_text = {
				{
					table.concat(
						vim.iter(self.search.opts.info_list)
							:map(function(info)
								return format_prompt_info(self.search, info)
							end)
							:totable(),
						' '
					),
					'BetterSelectInfo',
				},
			},
			virt_text_pos = 'eol_right_align',
			priority = ext_priority.info,
		})
	end
end

function View:scroll_to_selection()
	self.search:clamp_selection()
	if self.search.idx == 0 then
		self.offset = 0
		return
	end

	local minimum_offset = self.search.idx - self.max_list_height
	if minimum_offset > self.offset then
		self.offset = minimum_offset
	elseif self.search.idx <= self.offset then
		self.offset = self.search.idx - 1
	end

	self.offset = math.min(math.max(0, self.offset), math.max(0, #self.search.matches - self.max_list_height))
end

local icon_pad = 2

function View:draw_matches()
	local indent = vim.fn.strdisplaywidth(self.search.opts.pointer) + 1
	local prefix = (' '):rep(indent)
	self:scroll_to_selection()
	local lines = {}
	local last_match = math.min(#self.search.matches, self.max_list_height + self.offset)
	for index = self.offset + 1, last_match do
		local entry = self.search.items[self.search.matches[index][1]]
		if not (entry.icon and entry.icon_hl) and vim.is_callable(self.search.get_icon) then
			entry.icon, entry.icon_hl = self.search.get_icon(entry)
		end
		if not entry.hls and vim.is_callable(self.search.hl_item) then
			entry.hls = self.search.hl_item(entry)
		end
		local icon = entry.icon and (entry.icon .. (' '):rep(icon_pad)) or ''
		lines[#lines + 1] = prefix .. icon .. entry.text
	end
	if not self.search.opts.shrink then
		for _ = #lines + 1, self.max_list_height do
			lines[#lines + 1] = ''
		end
	end
	self:set_lines(self.start_row, cmdline.erow, lines)
	cmdline.erow = self.start_row + #lines

	for index = self.offset + 1, last_match do
		local match = self.search.matches[index]
		local entry = self.search.items[match[1]]
		local row = self.start_row + index - self.offset - 1
		local text_col = indent + (entry.icon and (#entry.icon + icon_pad) or 0)
		if entry.icon and entry.icon_hl then
			self:add_highlight(row, indent, {
				end_col = text_col,
				hl_group = entry.icon_hl,
				priority = ext_priority.icon,
			})
		end
		for _, highlight in ipairs(entry.hls or {}) do
			self:add_highlight(row, text_col + highlight[1][1], {
				end_col = text_col + highlight[1][2],
				hl_group = highlight[2],
				priority = ext_priority.hl,
			})
		end
		if self.search.marked[entry.id] then
			self:add_highlight(row, indent - 1, {
				virt_text = { { self.search.opts.marker, 'BetterSelectMark' } },
				virt_text_pos = 'overlay',
				priority = ext_priority.marker,
			})
			self:add_highlight(row, 0, {
				hl_group = 'BetterSelectMarkLine',
				hl_eol = true,
				end_row = row + 1,
				end_col = 0,
				priority = ext_priority.marker,
			})
		end
		for _, position in ipairs(match[2] or {}) do
			local byte = vim.fn.byteidx(entry.text, position)
			local next_byte = vim.fn.byteidx(entry.text, position + 1)
			self:add_highlight(row, text_col + byte, {
				hl_group = index == self.search.idx and 'BetterSelectMatchSel' or 'BetterSelectMatch',
				end_col = text_col + (next_byte < 0 and #entry.text or next_byte),
				priority = ext_priority.match,
			})
		end
	end
end

function View:highlight_selection()
	if self.search.idx == 0 then
		self:close_preview()
	elseif self.preview_win then
		self:update_preview()
	end

	self.search:clamp_selection()
	local idx = self.search.idx
	if idx == 0 then
		return
	end

	self:scroll_to_selection()
	local row = math.max(0, math.min(self.start_row + (idx - self.offset), cmdline.erow) - 1)

	self:add_highlight(row, 0, {
		virt_text = { { self.search.opts.pointer, 'BetterSelectPointer' } },
		virt_text_pos = 'overlay',

		hl_group = 'BetterSelectSel',
		hl_eol = true,
		end_row = row + 1,
		end_col = 0,

		priority = ext_priority.select,
	})
end

function View:toggle_preview()
	if self.preview_win then
		self:close_preview()
		return
	end

	self:update_preview()
end

---@return {buf?:integer, pos?:[integer,integer], pos_end?:[integer,integer]}?
function View:get_preview_content()
	if self.search.idx == 0 then
		return
	end

	local match = self.search.matches[self.search.idx]
	local item = self.search.items[match[1]]

	if not item or not (self.search.preview_item and vim.is_callable(self.search.preview_item)) then
		return
	end

	local ok, result = pcall(self.search.preview_item, item.v, item.id, self.search)
	if not ok then
		self.search:report_error(result)
		return
	end
	return result
end

function View:get_preview_window_options()
	local preview_opts = self.search.win.preview_opts
		and vim.is_callable(self.search.win.preview_opts)
		and self.search.win.preview_opts(self)
	local cmd_height = vim.api.nvim_win_get_height(ui2.wins.cmd)

	local win_border = preview_opts and preview_opts.border or vim.o.winborder
	return vim.tbl_extend('force', {
		relative = 'editor',
		focusable = false,
		width = vim.o.columns,
		height = self.win.height,
		col = 0,
		row = vim.o.lines
			- (self.win.height + cmd_height)
			- ((win_border == 'none' or win_border == '') and 0 or 2)
			- (self.search.win.hide_statusline and 0 or 1),
	}, preview_opts or {})
end

function View:update_preview()
	local pr = self:get_preview_content()
	if not pr or not pr.buf or not vim.api.nvim_buf_is_valid(pr.buf) then
		self:close_preview()
		return
	end
	vim.fn.bufload(pr.buf)

	if not self.preview_win then
		self.preview_win = vim.api.nvim_open_win(pr.buf, false, self:get_preview_window_options())
	else
		vim.api.nvim_win_set_buf(self.preview_win, pr.buf)
	end

	vim._with({ win = self.preview_win, noautocmd = true }, function()
		vim.api.nvim_set_option_value('previewwindow', true, { scope = 'local' })
		vim.api.nvim_set_option_value('eventignorewin', 'all,-FileType', { scope = 'local' })

		local same_line = pr.pos ~= nil and (pr.pos_end == nil or pr.pos_end[1] == pr.pos[1])
		vim.api.nvim_set_option_value('cursorline', same_line, { scope = 'local' })

		if pr.pos then
			vim.api.nvim_win_set_cursor(self.preview_win, pr.pos)
		end
	end)
end

function View:close_preview()
	if not self.preview_win then
		return
	end

	pcall(vim.api.nvim_win_close, self.preview_win, true)
	self.preview_win = nil
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
	mappings = {
		['<Down>'] = 'down',
		['<Up>'] = 'up',
		['<CR>'] = 'accept',
		['<Esc>'] = 'cancel',
		['<Tab>'] = 'mark',
		['<C-g>'] = 'toggle_live',
		['<C-l>'] = 'toggle_preview',
		['<C-q>'] = 'set_quickfix',
		['<C-s>'] = 'split',
		['<C-v>'] = 'vsplit',
		['<C-t>'] = 'tabnew',
	},
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
---@field on_cancel? fun(search: table)
---@field preview_item? fun(item: any, index: integer, search: table): table? {buf, pos?, pos_end?}
---@field get_icon? fun(entry: better_select.Entry): string?, string?
---@field hl_item? fun(entry: better_select.Entry): table[]?
---@field to_quickfix? fun(item: any, index: integer): table
---@field sorter? fun(entries: better_select.Entry[], query: string): table[] {index, character_positions, score}
---@field actions? table<string, fun(search: table)>
---@field mappings? table<string, string|false>
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
		self.view:redraw()
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
		self.view:redraw()
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
		self.view:redraw()
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
			if self.saved_maps[key] then
				vim.api.nvim_buf_call(self.buf, function()
					vim.fn.mapset('i', false, self.saved_maps[key])
				end)
			end
		end
		self.view:close()
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
			self.view:redraw()
		elseif name == 'mark' then
			local entry = self:get_current()
			if entry then
				self.marked[entry.id] = not self.marked[entry.id] or nil
				self.view:redraw()
			end
		elseif name == 'toggle_preview' then
			self.view:toggle_preview()
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
	prompt_hl_id = vim.api.nvim_get_hl_id_by_name 'BetterSelectPrompt'
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
	self.keys, self.saved_maps = {}, {}
	self.view = View:new(self)
	local ok, err = pcall(function()
		self.view:open()
		for key, action in pairs(self.mappings) do
			if action then
				local previous = vim.fn.maparg(key, 'i', false, true)
				if previous.buffer == 1 then
					self.saved_maps[key] = previous
				end
				self.keys[#self.keys + 1] = key
				vim.keymap.set('i', key, function()
					self:action(action)
				end, { buffer = self.buf, nowait = true })
			end
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
