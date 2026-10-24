-- Adapted from comfysage/artio.nvim (EUPL-1.2).
-- Modified 2026-10-06: generic source lifecycle, synchronous cleanup, UTF-8 highlights.
-- See LICENSE and NOTICE in this directory.
local cmdline = require 'vim._core.ui2.cmdline'
local ui2 = require 'vim._core.ui2'

---@alias enhanced_select.CmdContent {[1]: integer, [2]: string}[] Highlight ID and text chunks

local view_ns = vim.api.nvim_create_namespace '@enhanced_select.view.ns'
local prompt_hl_id = vim.api.nvim_get_hl_id_by_name 'EnhancedSelectPrompt'

---@class enhanced_select.View
---@field search enhanced_select.EnhancedSelect
---@field closed boolean
---@field opts table<'win'|'buf'|'g',table<string,any>>
---@field marks table<string|integer, integer>
---@field win enhanced_select.View.win
---@field preview_win integer
local View = {}
View.__index = View

---@param search enhanced_select.EnhancedSelect
function View:new(search)
	return setmetatable({
		search = search,
		closed = false,
		opts = {},
		marks = {},
		win = {
			height = 1,
		},
	}, View)
end

---@class enhanced_select.View.win
---@field height integer

local active_prompt_hl_id = -1

local query_text = '' ---@type string Unescaped query text; its byte length positions the initial cursor.
local prompt_length = 0 -- Byte length of the prompt prefix, excluding query text.
local prompt_row = 0
--- Concatenate content chunks and set the text for the current row in the cmdline buffer.
---
---@param content enhanced_select.CmdContent
---@param prompt string
function View:set_prompt_text(content, prompt)
	local lines = {} ---@type string[]
	for line in (prompt .. '\n'):gmatch '(.-)\n' do
		lines[#lines + 1] = vim.fn.strtrans(line)
	end

	local prompt_string = lines[#lines]
	prompt_length = #lines[#lines]

	query_text = ''
	for _, chunk in ipairs(content) do
		query_text = query_text .. chunk[2]
	end
	lines[#lines] = ('%s%s'):format(prompt_string, vim.fn.strtrans(query_text))

	self:update_prompt_position()
	self:set_lines(prompt_row, prompt_row + 1, lines)
	if vim.fn.prompt_getprompt(ui2.bufs.cmd) ~= prompt_string then
		vim.fn.prompt_setprompt(ui2.bufs.cmd, prompt_string)
	end
	pcall(vim.api.nvim_buf_set_mark, ui2.bufs.cmd, ':', prompt_row + 1, prompt_length, {})
end

--- Set the cmdline buffer text and cursor position.
---
---@param content enhanced_select.CmdContent
---@param pos? integer
---@param first_char string
---@param prompt string
---@param indent integer
---@param level integer
---@param hl_id integer
function View:render(content, pos, first_char, prompt, indent, level, hl_id)
	cmdline.level, cmdline.indent = level, indent
	if cmdline.highlighter and cmdline.highlighter.active then
		cmdline.highlighter.active[ui2.bufs.cmd] = nil
	end
	if ui2.msg.cmd.msg_row ~= -1 then
		ui2.msg.msg_clear()
	end
	ui2.msg.virt.last = { {}, {}, {}, {} }

	self:clear()
	active_prompt_hl_id = hl_id

	self:show_matches()

	self:set_prompt_text(content, ('%s%s%s'):format(first_char, prompt, (' '):rep(indent)))
	self:update_cursor(pos)

	self:update_win_height()

	self:draw_prompt()
	self:highlight_selection()
end

--- Set the 'cmd_height' and cmdline window height. Reposition message windows.
---
---@param win integer Cmdline window in the current tabpage.
---@param hide boolean Whether to hide or show the window.
---@param height integer (Text)height of the cmdline window.
function View:win_config(win, hide, height)
	if ui2.cmdheight == 0 and vim.api.nvim_win_get_config(win).hide ~= hide then
		vim.api.nvim_win_set_config(win, { hide = hide, height = not hide and height or nil })
	elseif vim.api.nvim_win_get_height(win) ~= height then
		vim.api.nvim_win_set_height(win, height)
	end

	if not hide and self.search.win.hide_statusline then
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
		vim.api.nvim_win_set_config(self.preview_win, self:preview_config())
	end
end

---@param predicted? integer The predicted height of the cmdline window
function View:update_win_height(predicted)
	local height = math.max(1, predicted or vim.api.nvim_win_text_height(ui2.wins.cmd, {}).all)
	height = math.min(height, self.win.height)
	self:win_config(ui2.wins.cmd, false, height)
end

function View:save_view()
	self.save = vim.fn.winsaveview()
	self.previous_win = vim.api.nvim_get_current_win()
end

function View:restore_view()
	vim.api.nvim_set_current_win(self.previous_win)
	vim.fn.winrestview(self.save)
end

---@param restore? boolean
function View:set_opts(restore)
	local opts = {
		win = {
			eventignorewin = 'all,-FileType,-InsertCharPre,-TextChangedI,-CursorMovedI,-InsertLeave,-BufLeave,-WinLeave',
			winhighlight = 'Normal:EnhancedSelectNormal,Search:,CurSearch:,IncSearch:',
			signcolumn = 'no',
			wrap = false,
		},
		buf = {
			filetype = 'enhanced-select',
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

local max_list_height = 1 -- Max height of the matches list (`self.win.height - 1`)

function View:on_resized()
	if self.search.win.height > 1 then
		self.win.height = self.search.win.height
	else
		self.win.height = vim.o.lines * self.search.win.height
	end
	self.win.height = math.min(math.max(math.ceil(self.win.height), 2), math.max(2, vim.o.lines - 2))

	max_list_height = math.max(self.win.height - 1, 1)
end

function View:open()
	self.augroup = vim.api.nvim_create_augroup('@enhanced_select.view', { clear = true })
	self:save_view()
	self.saved_prompt = vim.fn.prompt_getprompt(ui2.bufs.cmd)
	self:on_resized()
	cmdline.prompt, cmdline.srow, cmdline.indent, cmdline.level = false, 0, 1, 1
	self:redraw()
	vim._with({ noautocmd = true }, function()
		vim.api.nvim_set_current_win(ui2.wins.cmd)
	end)
	self:set_opts()
	self:update_cursor(#query_text)
	vim._with({ noautocmd = true }, function()
		vim.cmd.startinsert { bang = true }
	end)
	vim.api.nvim_create_autocmd('TextChangedI', {
		group = self.augroup,
		buffer = ui2.bufs.cmd,
		callback = function()
			self:update()
		end,
	})
	vim.api.nvim_create_autocmd('CursorMovedI', {
		group = self.augroup,
		buffer = ui2.bufs.cmd,
		callback = function()
			self:update_cursor()
		end,
	})
	vim.api.nvim_create_autocmd('VimResized', {
		group = self.augroup,
		callback = function()
			self:on_resized()
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
	self:set_opts(true)
	vim.api.nvim_buf_clear_namespace(ui2.bufs.cmd, view_ns, 0, -1)
	self:clear()
	cmdline.srow, cmdline.erow = 0, 0
	self:hide()
	if vim.api.nvim_win_is_valid(self.previous_win) then
		self:restore_view()
	end
end

function View:hide()
	vim.fn.clearmatches(ui2.wins.cmd) -- Clear matchparen highlights.
	vim.api.nvim_win_set_cursor(ui2.wins.cmd, { 1, 0 })
	vim.api.nvim_buf_set_lines(ui2.bufs.cmd, 0, -1, false, {})

	cmdline.prompt, cmdline.level = false, 0
	self:win_config(ui2.wins.cmd, true, ui2.cmdheight)
end

function View:redraw()
	local input
	if self.search.live then
		input = self.search.live_input
	else
		input = self.search.input
	end
	self:render({ { 0, input } }, -1, '', self.search.prompt_text, cmdline.indent, cmdline.level, prompt_hl_id)
end

function View:update()
	if self.closed then
		return
	end
	local text = vim.api.nvim_buf_get_lines(ui2.bufs.cmd, prompt_row, prompt_row + 1, false)[1] or ''
	text = text:sub(prompt_length + 1)
	if text ~= (self.search.live and self.search.live_input or self.search.input) then
		self.search:set_query(text)
	end
end

---@param pos? integer Zero-based query byte offset; nil or negative preserves the cursor position
function View:update_cursor(pos)
	self.cursor_pos = self.cursor_pos or { 0, 0 }

	self:update_prompt_position()

	if not pos or pos < 0 then
		local cursor_pos = vim.api.nvim_win_get_cursor(ui2.wins.cmd)
		pos = cursor_pos[2] - prompt_length
	end

	-- Keep the cursor out of the noneditable prompt prefix.
	self.cursor_pos[2] = math.max(self.cursor_pos[2], prompt_length)

	if self.cursor_pos[1] == prompt_row + 1 and self.cursor_pos[2] == prompt_length + pos then
		return
	end

	if pos < 0 then
		-- Reuse the last query position when the cursor enters the prompt prefix.
		pos = self.cursor_pos[2] - prompt_length
	end

	self.cursor_pos[1], self.cursor_pos[2] = prompt_row + 1, prompt_length + pos

	vim._with({ noautocmd = true }, function()
		local ok, _ = pcall(vim.api.nvim_win_set_cursor, ui2.wins.cmd, self.cursor_pos)
		if not ok then
			self.search:report(('Failed to set cursor %d:%d'):format(self.cursor_pos[1], self.cursor_pos[2]))
		end
	end)
end

local start_row = 0

function View:clear()
	start_row = self.search.opts.bottom and 0 or 1
	cmdline.erow = start_row
	vim.api.nvim_buf_clear_namespace(ui2.bufs.cmd, view_ns, 0, -1)
	self.marks = {}
	self:set_lines(0, -1, {})
end

function View:update_prompt_position()
	prompt_row = self.search.opts.bottom and cmdline.erow or 0
end

function View:set_lines(start_pos, end_pos, lines)
	-- Grow the window before adding rows so the prompt stays visible.
	local diff = #lines - (end_pos - start_pos)
	if diff ~= 0 then
		local height = vim.api.nvim_win_text_height(ui2.wins.cmd, {}).all
		local predicted = height + diff
		self:update_win_height(predicted)
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

---@param id? string|integer
---@param line integer 0-based
---@param col integer 0-based
---@param opts vim.api.keyset.set_extmark
---@return integer
function View:mark(id, line, col, opts)
	if id and self.marks[id] then
		vim._with({ noautocmd = true }, function()
			vim.api.nvim_buf_del_extmark(ui2.bufs.cmd, view_ns, self.marks[id])
		end)
		self.marks[id] = nil
	end

	opts.hl_mode = 'combine'
	opts.invalidate = true

	local ok, result
	vim._with({ noautocmd = true }, function()
		ok, result = pcall(vim.api.nvim_buf_set_extmark, ui2.bufs.cmd, view_ns, line, col, opts)
	end)
	if not ok then
		self.search:report(('Failed to add extmark %d:%d\n\t%s'):format(line, col, result))
		return -1
	end

	if id and result >= 0 then
		self.marks[id] = result
	end

	return result
end

---@param p enhanced_select.EnhancedSelect
---@param info 'index'|'list'|string
---@return string
local function get_prompt_info(p, info)
	if info == 'index' then
		return ('[%d]'):format(p.idx)
	elseif info == 'list' then
		return ('(%d/%d)'):format(#p.matches, p.items and #p.items or 0)
	end
	return ''
end

function View:draw_prompt()
	self:update_prompt_position()
	if prompt_length > 0 and active_prompt_hl_id > 0 then
		self:mark(
			'prompthl',
			prompt_row,
			0,
			{ hl_group = active_prompt_hl_id, end_col = prompt_length, priority = ext_priority.prompt }
		)
		self:mark('promptinfo', prompt_row, 0, {
			virt_text = {
				{
					table.concat(
						vim.iter(self.search.opts.info_list)
							:map(function(info)
								return get_prompt_info(self.search, info)
							end)
							:totable(),
						' '
					),
					'EnhancedSelectInfo',
				},
			},
			virt_text_pos = 'eol_right_align',
			priority = ext_priority.info,
		})
	end
end

local offset = 0

function View:update_offset()
	self.search:clamp()
	if self.search.idx == 0 then
		offset = 0
		return
	end

	local _offset = self.search.idx - max_list_height
	if _offset > offset then
		offset = _offset
	elseif self.search.idx <= offset then
		offset = self.search.idx - 1
	end

	offset = math.min(math.max(0, offset), math.max(0, #self.search.matches - max_list_height))
end

local icon_pad = 2

function View:show_matches()
	local indent = vim.fn.strdisplaywidth(self.search.opts.pointer) + 1
	local prefix = (' '):rep(indent)
	local icon_pad_str = (' '):rep(icon_pad)

	if self.search.idx <= 1 then
		offset = 0
	end
	self:update_offset()

	local lines = {} ---@type string[]
	local hls = {}
	local icons = {} ---@type ([string, string]|false)[]
	local custom_hls = {} ---@type (enhanced_select.Highlight[]|false)[]
	local marks = {} ---@type boolean[]
	for i = 1 + offset, math.min(#self.search.matches, max_list_height + offset) do
		local match = self.search.matches[i]
		local item = self.search.items[match[1]]

		local icon, icon_hl = item.icon, item.icon_hl
		if not (icon and icon_hl) and vim.is_callable(self.search.get_icon) then
			icon, icon_hl = self.search.get_icon(item)
			item.icon, item.icon_hl = icon, icon_hl
		end
		icons[#icons + 1] = icon and { icon, icon_hl } or false
		icon = icon and ('%s%s'):format(item.icon, icon_pad_str) or ''

		local hl = item.hls
		if not hl and vim.is_callable(self.search.hl_item) then
			hl = self.search.hl_item(item)
			item.hls = hl
		end
		custom_hls[#custom_hls + 1] = hl or false

		marks[#marks + 1] = self.search.marked[item.id] or false

		lines[#lines + 1] = ('%s%s%s'):format(prefix, icon, item.text)
		hls[#hls + 1] = match[2]
	end

	if not self.search.opts.shrink then
		for _ = 1, (max_list_height - #lines) do
			lines[#lines + 1] = ''
		end
	end
	self:set_lines(start_row, cmdline.erow, lines)
	cmdline.erow = start_row + #lines

	for i = 1, #lines do
		local has_icon = icons[i] and icons[i][1] and true
		local icon_indent = has_icon and (#icons[i][1] + icon_pad) or 0

		if has_icon and icons[i][2] then
			self:mark(nil, start_row + i - 1, indent, {
				end_col = indent + icon_indent,
				hl_group = icons[i][2],
				priority = ext_priority.icon,
			})
		end

		local line_hls = custom_hls[i]
		if line_hls then
			for j = 1, #line_hls do
				local hl = line_hls[j]
				self:mark(nil, start_row + i - 1, indent + icon_indent + hl[1][1], {
					end_col = indent + icon_indent + hl[1][2],
					hl_group = hl[2],
					priority = ext_priority.hl,
				})
			end
		end

		if marks[i] then
			self:mark(nil, start_row + i - 1, indent - 1, {
				virt_text = { { self.search.opts.marker, 'EnhancedSelectMark' } },
				virt_text_pos = 'overlay',
				priority = ext_priority.marker,
			})
			self:mark(nil, start_row + i - 1, 0, {
				hl_group = 'EnhancedSelectMarkLine',
				hl_eol = true,
				end_row = start_row + i,
				end_col = 0,

				priority = ext_priority.marker,
			})
		end

		if hls[i] then
			for j = 1, #hls[i] do
				local text = self.search.items[self.search.matches[offset + i][1]].text
				local byte = vim.fn.byteidx(text, hls[i][j])
				local next_byte = vim.fn.byteidx(text, hls[i][j] + 1)
				local col = indent + icon_indent + byte
				self:mark(nil, start_row + i - 1, col, {
					hl_group = offset + i == self.search.idx and 'EnhancedSelectMatchSel' or 'EnhancedSelectMatch',
					end_col = indent + icon_indent + (next_byte < 0 and #text or next_byte),
					priority = ext_priority.match,
				})
			end
		end
	end
end

function View:highlight_selection()
	self:soft_update_preview()

	self.search:clamp()
	local idx = self.search.idx
	if idx == 0 then
		return
	end

	self:update_offset()
	local row = math.max(0, math.min(start_row + (idx - offset), cmdline.erow) - 1)

	self:mark('highlight_selection', row, 0, {
		virt_text = { { self.search.opts.pointer, 'EnhancedSelectPointer' } },
		virt_text_pos = 'overlay',

		hl_group = 'EnhancedSelectSel',
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
function View:open_preview()
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
		self.search:report(result)
		return
	end
	return result
end

function View:preview_config()
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
	local pr = self:open_preview()
	if not pr or not pr.buf or not vim.api.nvim_buf_is_valid(pr.buf) then
		self:close_preview()
		return
	end
	vim.fn.bufload(pr.buf)

	if not self.preview_win then
		self.preview_win = vim.api.nvim_open_win(pr.buf, false, self:preview_config())
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

function View:soft_update_preview()
	if self.search.idx == 0 then
		self:close_preview()
	end

	if not self.preview_win then
		return
	end

	self:update_preview()
end

function View:close_preview()
	if not self.preview_win then
		return
	end

	pcall(vim.api.nvim_win_close, self.preview_win, true)
	self.preview_win = nil
end

return View
