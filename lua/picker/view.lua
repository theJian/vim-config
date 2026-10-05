-- Adapted from comfysage/artio.nvim (EUPL-1.2).
-- Modified 2026-10-06: generic source lifecycle, synchronous cleanup, UTF-8 highlights.
-- See LICENSE and NOTICE in this directory.
local cmdline = require 'vim._core.ui2.cmdline'
local ui2 = require 'vim._core.ui2'

local view_ns = vim.api.nvim_create_namespace '@picker.view.ns'
local prompt_hl_id = vim.api.nvim_get_hl_id_by_name 'PickerPrompt'

---@class picker.View
---@field picker picker.Picker
---@field closed boolean
---@field opts table<'win'|'buf'|'g',table<string,any>>
---@field marks table<string|integer, integer>
---@field win picker.View.win
---@field preview_win integer
local View = {}
View.__index = View

---@param picker picker.Picker
function View:new(picker)
	return setmetatable({
		picker = picker,
		closed = false,
		opts = {},
		marks = {},
		win = {
			height = 1,
		},
	}, View)
end

---@class picker.View.win
---@field height integer

local prompthl_id = -1

local cmdbuff = '' ---@type string Stored cmdline used to calculate translation offset.
local promptlen = 0 -- Current length of the last line in the prompt.
local promptidx = 0
--- Concatenate content chunks and set the text for the current row in the cmdline buffer.
---
---@param content CmdContent
---@param prompt string
function View:setprompttext(content, prompt)
	local lines = {} ---@type string[]
	for line in (prompt .. '\n'):gmatch '(.-)\n' do
		lines[#lines + 1] = vim.fn.strtrans(line)
	end

	local promptstr = lines[#lines]
	promptlen = #lines[#lines]

	cmdbuff = ''
	for _, chunk in ipairs(content) do
		cmdbuff = cmdbuff .. chunk[2]
	end
	lines[#lines] = ('%s%s'):format(promptstr, vim.fn.strtrans(cmdbuff))

	self:promptpos()
	self:setlines(promptidx, promptidx + 1, lines)
	if vim.fn.prompt_getprompt(ui2.bufs.cmd) ~= promptstr then
		vim.fn.prompt_setprompt(ui2.bufs.cmd, promptstr)
	end
	pcall(vim.api.nvim_buf_set_mark, ui2.bufs.cmd, ':', promptidx + 1, promptlen, {})
end

--- Set the cmdline buffer text and cursor position.
---
---@param content CmdContent
---@param pos? integer
---@param firstc string
---@param prompt string
---@param indent integer
---@param level integer
---@param hl_id integer
function View:show(content, pos, firstc, prompt, indent, level, hl_id)
	cmdline.level, cmdline.indent = level, indent
	if cmdline.highlighter and cmdline.highlighter.active then
		cmdline.highlighter.active[ui2.bufs.cmd] = nil
	end
	if ui2.msg.cmd.msg_row ~= -1 then
		ui2.msg.msg_clear()
	end
	ui2.msg.virt.last = { {}, {}, {}, {} }

	self:clear()
	prompthl_id = hl_id

	self:showmatches()

	self:setprompttext(content, ('%s%s%s'):format(firstc, prompt, (' '):rep(indent)))
	self:updatecursor(pos)

	self:updatewinheight()

	self:drawprompt()
	self:hlselect()
end

--- Set the 'cmdheight' and cmdline window height. Reposition message windows.
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

	if not hide and self.picker.win.hidestatusline then
		height = 0
	end

	if vim.o.cmdheight ~= height then
		-- Avoid moving the cursor with 'splitkeep' = "screen", and altering the user
		-- configured value with noautocmd.
		vim._with({ noautocmd = true, o = { splitkeep = 'screen' } }, function()
			vim.o.cmdheight = height
		end)
		ui2.msg.set_pos()
	end

	if self.preview_win and vim.api.nvim_win_is_valid(self.preview_win) then
		vim.api.nvim_win_set_config(self.preview_win, self:previewconfig())
	end
end

---@param predicted? integer The predicted height of the cmdline window
function View:updatewinheight(predicted)
	local height = math.max(1, predicted or vim.api.nvim_win_text_height(ui2.wins.cmd, {}).all)
	height = math.min(height, self.win.height)
	self:win_config(ui2.wins.cmd, false, height)
end

function View:saveview()
	self.save = vim.fn.winsaveview()
	self.prevwin = vim.api.nvim_get_current_win()
end

function View:restoreview()
	vim.api.nvim_set_current_win(self.prevwin)
	vim.fn.winrestview(self.save)
end

local ext_winhl = 'Search:,CurSearch:,IncSearch:'

---@param restore? boolean
function View:setopts(restore)
	local opts = {
		win = {
			eventignorewin = 'all,-FileType,-InsertCharPre,-TextChangedI,-CursorMovedI,-InsertLeave,-BufLeave,-WinLeave',
			winhighlight = 'Normal:PickerNormal,' .. ext_winhl,
			signcolumn = 'no',
			wrap = false,
		},
		buf = {
			filetype = 'generic-picker',
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

local maxlistheight = 1 -- Max height of the matches list (`self.win.height - 1`)

function View:on_resized()
	if self.picker.win.height > 1 then
		self.win.height = self.picker.win.height
	else
		self.win.height = vim.o.lines * self.picker.win.height
	end
	self.win.height = math.min(math.max(math.ceil(self.win.height), 2), math.max(2, vim.o.lines - 2))

	maxlistheight = math.max(self.win.height - 1, 1)
end

function View:open()
	self.augroup = vim.api.nvim_create_augroup('@picker.view', { clear = true })
	self:saveview()
	self.saved_prompt = vim.fn.prompt_getprompt(ui2.bufs.cmd)
	self:on_resized()
	cmdline.prompt, cmdline.srow, cmdline.indent, cmdline.level = false, 0, 1, 1
	self:trigger_show()
	vim._with({ noautocmd = true }, function()
		vim.api.nvim_set_current_win(ui2.wins.cmd)
	end)
	self:setopts()
	self:updatecursor(#cmdbuff)
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
			self:updatecursor()
		end,
	})
	vim.api.nvim_create_autocmd('VimResized', {
		group = self.augroup,
		callback = function()
			self:on_resized()
			self:trigger_show()
		end,
	})
	vim.api.nvim_create_autocmd('ModeChanged', {
		group = self.augroup,
		pattern = 'i:*',
		callback = function()
			self.picker:cancel()
		end,
	})
	vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufLeave', 'WinLeave' }, {
		group = self.augroup,
		buffer = ui2.bufs.cmd,
		callback = function()
			self.picker:cancel()
		end,
	})
end

function View:close()
	if self.closed then
		return
	end
	self.closed = true
	pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
	self:closepreview()
	vim.cmd.stopinsert()
	vim.fn.prompt_setprompt(ui2.bufs.cmd, self.saved_prompt or '')
	self:setopts(true)
	vim.api.nvim_buf_clear_namespace(ui2.bufs.cmd, view_ns, 0, -1)
	self:clear()
	cmdline.srow, cmdline.erow = 0, 0
	self:hide()
	if vim.api.nvim_win_is_valid(self.prevwin) then
		self:restoreview()
	end
end

function View:hide()
	vim.fn.clearmatches(ui2.wins.cmd) -- Clear matchparen highlights.
	vim.api.nvim_win_set_cursor(ui2.wins.cmd, { 1, 0 })
	vim.api.nvim_buf_set_lines(ui2.bufs.cmd, 0, -1, false, {})

	cmdline.prompt, cmdline.level = false, 0
	self:win_config(ui2.wins.cmd, true, ui2.cmdheight)
end

function View:trigger_show()
	local input
	if self.picker.live then
		input = self.picker.liveinput
	else
		input = self.picker.input
	end
	self:show({ { 0, input } }, -1, '', self.picker.prompttext, cmdline.indent, cmdline.level, prompt_hl_id)
end

---@param force? boolean
function View:update()
	if self.closed then
		return
	end
	local text = vim.api.nvim_buf_get_lines(ui2.bufs.cmd, promptidx, promptidx + 1, false)[1] or ''
	text = text:sub(promptlen + 1)
	if text ~= (self.picker.live and self.picker.liveinput or self.picker.input) then
		self.picker:set_query(text)
	end
end

---@param pos? integer relative to prompt
function View:updatecursor(pos)
	self.curpos = self.curpos or { 0, 0 }

	self:promptpos()

	if not pos or pos < 0 then
		local cursorpos = vim.api.nvim_win_get_cursor(ui2.wins.cmd)
		pos = cursorpos[2] - promptlen
	end

	-- set cursor pos to *at least* the prompt length
	self.curpos[2] = math.max(self.curpos[2], promptlen)

	if self.curpos[1] == promptidx + 1 and self.curpos[2] == promptlen + pos then
		return
	end

	if pos < 0 then
		-- reset to last known position
		pos = self.curpos[2] - promptlen
	end

	self.curpos[1], self.curpos[2] = promptidx + 1, promptlen + pos

	vim._with({ noautocmd = true }, function()
		local ok, _ = pcall(vim.api.nvim_win_set_cursor, ui2.wins.cmd, self.curpos)
		if not ok then
			self.picker:report(('Failed to set cursor %d:%d'):format(self.curpos[1], self.curpos[2]))
		end
	end)
end

local srow = 0

function View:clear()
	srow = self.picker.opts.bottom and 0 or 1
	cmdline.erow = srow
	vim.api.nvim_buf_clear_namespace(ui2.bufs.cmd, view_ns, 0, -1)
	self.marks = {}
	self:setlines(0, -1, {})
end

function View:promptpos()
	promptidx = self.picker.opts.bottom and cmdline.erow or 0
end

function View:setlines(posstart, posend, lines)
	-- update winheight to prevent wrong scroll when increasing from 1
	local diff = #lines - (posend - posstart)
	if diff ~= 0 then
		local height = vim.api.nvim_win_text_height(ui2.wins.cmd, {}).all
		local predicted = height + diff
		self:updatewinheight(predicted)
	end

	vim.api.nvim_buf_set_lines(ui2.bufs.cmd, posstart, posend, false, lines)
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
		self.picker:report(('Failed to add extmark %d:%d\n\t%s'):format(line, col, result))
		return -1
	end

	if id and result >= 0 then
		self.marks[id] = result
	end

	return result
end

---@param p picker.Picker
---@param info 'index'|'list'|string
---@return string
local function getpromptinfo(p, info)
	if info == 'index' then
		return ('[%d]'):format(p.idx)
	elseif info == 'list' then
		return ('(%d/%d)'):format(#p.matches, p.items and #p.items or 0)
	end
	return ''
end

function View:drawprompt()
	self:promptpos()
	if promptlen > 0 and prompthl_id > 0 then
		self:mark(
			'prompthl',
			promptidx,
			0,
			{ hl_group = prompthl_id, end_col = promptlen, priority = ext_priority.prompt }
		)
		self:mark('promptinfo', promptidx, 0, {
			virt_text = {
				{
					table.concat(
						vim.iter(self.picker.opts.infolist)
							:map(function(info)
								return getpromptinfo(self.picker, info)
							end)
							:totable(),
						' '
					),
					'InfoText',
				},
			},
			virt_text_pos = 'eol_right_align',
			priority = ext_priority.info,
		})
	end
end

local offset = 0

function View:updateoffset()
	self.picker:fix()
	if self.picker.idx == 0 then
		offset = 0
		return
	end

	local _offset = self.picker.idx - maxlistheight
	if _offset > offset then
		offset = _offset
	elseif self.picker.idx <= offset then
		offset = self.picker.idx - 1
	end

	offset = math.min(math.max(0, offset), math.max(0, #self.picker.matches - maxlistheight))
end

local icon_pad = 2

function View:showmatches()
	local indent = vim.fn.strdisplaywidth(self.picker.opts.pointer) + 1
	local prefix = (' '):rep(indent)
	local icon_pad_str = (' '):rep(icon_pad)

	if self.picker.idx <= 1 then
		offset = 0
	end
	self:updateoffset()

	local lines = {} ---@type string[]
	local hls = {}
	local icons = {} ---@type ([string, string]|false)[]
	local custom_hls = {} ---@type (picker.Picker.hl[]|false)[]
	local marks = {} ---@type boolean[]
	for i = 1 + offset, math.min(#self.picker.matches, maxlistheight + offset) do
		local match = self.picker.matches[i]
		local item = self.picker.items[match[1]]

		local icon, icon_hl = item.icon, item.icon_hl
		if not (icon and icon_hl) and vim.is_callable(self.picker.get_icon) then
			icon, icon_hl = self.picker.get_icon(item)
			item.icon, item.icon_hl = icon, icon_hl
		end
		icons[#icons + 1] = icon and { icon, icon_hl } or false
		icon = icon and ('%s%s'):format(item.icon, icon_pad_str) or ''

		local hl = item.hls
		if not hl and vim.is_callable(self.picker.hl_item) then
			hl = self.picker.hl_item(item)
			item.hls = hl
		end
		custom_hls[#custom_hls + 1] = hl or false

		marks[#marks + 1] = self.picker.marked[item.id] or false

		lines[#lines + 1] = ('%s%s%s'):format(prefix, icon, item.text)
		hls[#hls + 1] = match[2]
	end

	if not self.picker.opts.shrink then
		for _ = 1, (maxlistheight - #lines) do
			lines[#lines + 1] = ''
		end
	end
	self:setlines(srow, cmdline.erow, lines)
	cmdline.erow = srow + #lines

	for i = 1, #lines do
		local has_icon = icons[i] and icons[i][1] and true
		local icon_indent = has_icon and (#icons[i][1] + icon_pad) or 0

		if has_icon and icons[i][2] then
			self:mark(nil, srow + i - 1, indent, {
				end_col = indent + icon_indent,
				hl_group = icons[i][2],
				priority = ext_priority.icon,
			})
		end

		local line_hls = custom_hls[i]
		if line_hls then
			for j = 1, #line_hls do
				local hl = line_hls[j]
				self:mark(nil, srow + i - 1, indent + icon_indent + hl[1][1], {
					end_col = indent + icon_indent + hl[1][2],
					hl_group = hl[2],
					priority = ext_priority.hl,
				})
			end
		end

		if marks[i] then
			self:mark(nil, srow + i - 1, indent - 1, {
				virt_text = { { self.picker.opts.marker, 'PickerMark' } },
				virt_text_pos = 'overlay',
				priority = ext_priority.marker,
			})
			self:mark(nil, srow + i - 1, 0, {
				hl_group = 'PickerMarkLine',
				hl_eol = true,
				end_row = srow + i,
				end_col = 0,

				priority = ext_priority.marker,
			})
		end

		if hls[i] then
			for j = 1, #hls[i] do
				local text = self.picker.items[self.picker.matches[offset + i][1]].text
				local byte = vim.fn.byteidx(text, hls[i][j])
				local nextbyte = vim.fn.byteidx(text, hls[i][j] + 1)
				local col = indent + icon_indent + byte
				self:mark(nil, srow + i - 1, col, {
					hl_group = 'PickerMatch',
					end_col = indent + icon_indent + (nextbyte < 0 and #text or nextbyte),
					priority = ext_priority.match,
				})
			end
		end
	end
end

function View:hlselect()
	self:softupdatepreview()

	self.picker:fix()
	local idx = self.picker.idx
	if idx == 0 then
		return
	end

	self:updateoffset()
	local row = math.max(0, math.min(srow + (idx - offset), cmdline.erow) - 1)

	self:mark('hlselect', row, 0, {
		virt_text = { { self.picker.opts.pointer, 'PickerPointer' } },
		virt_text_pos = 'overlay',

		hl_group = 'PickerSel',
		hl_eol = true,
		end_row = row + 1,
		end_col = 0,

		priority = ext_priority.select,
	})
end

function View:togglepreview()
	if self.preview_win then
		self:closepreview()
		return
	end

	self:updatepreview()
end

---@return {buf?:integer, pos?:[integer,integer], pos_end?:[integer,integer]}?
function View:openpreview()
	if self.picker.idx == 0 then
		return
	end

	local match = self.picker.matches[self.picker.idx]
	local item = self.picker.items[match[1]]

	if not item or not (self.picker.preview_item and vim.is_callable(self.picker.preview_item)) then
		return
	end

	local ok, result = pcall(self.picker.preview_item, item.v, item.id, self.picker)
	if not ok then
		self.picker:report(result)
		return
	end
	return result
end

function View:previewconfig()
	local previewopts = self.picker.win.preview_opts
		and vim.is_callable(self.picker.win.preview_opts)
		and self.picker.win.preview_opts(self)
	local cmdheight = vim.api.nvim_win_get_height(ui2.wins.cmd)

	local winborder = previewopts and previewopts.border or vim.o.winborder
	return vim.tbl_extend('force', {
		relative = 'editor',
		focusable = false,
		width = vim.o.columns,
		height = self.win.height,
		col = 0,
		row = vim.o.lines
			- (self.win.height + cmdheight)
			- ((winborder == 'none' or winborder == '') and 0 or 2)
			- (self.picker.win.hidestatusline and 0 or 1),
	}, previewopts or {})
end

function View:updatepreview()
	local pr = self:openpreview()
	if not pr or not pr.buf or not vim.api.nvim_buf_is_valid(pr.buf) then
		self:closepreview()
		return
	end
	vim.fn.bufload(pr.buf)

	if not self.preview_win then
		self.preview_win = vim.api.nvim_open_win(pr.buf, false, self:previewconfig())
	else
		vim.api.nvim_win_set_buf(self.preview_win, pr.buf)
	end

	vim._with({ win = self.preview_win, noautocmd = true }, function()
		vim.api.nvim_set_option_value('previewwindow', true, { scope = 'local' })
		vim.api.nvim_set_option_value('eventignorewin', 'all,-FileType', { scope = 'local' })

		local sameline = pr.pos ~= nil and (pr.pos_end == nil or pr.pos_end[1] == pr.pos[1])
		vim.api.nvim_set_option_value('cursorline', sameline, { scope = 'local' })

		if pr.pos then
			vim.api.nvim_win_set_cursor(self.preview_win, pr.pos)
		end
	end)
end

function View:softupdatepreview()
	if self.picker.idx == 0 then
		self:closepreview()
	end

	if not self.preview_win then
		return
	end

	self:updatepreview()
end

function View:closepreview()
	if not self.preview_win then
		return
	end

	pcall(vim.api.nvim_win_close, self.preview_win, true)
	self.preview_win = nil
end

return View
