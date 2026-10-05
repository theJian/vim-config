-- Generic ui2 picker. Licensed under EUPL-1.2; see LICENSE and NOTICE.
local M = {}
---@class picker.Picker: picker.Options
---@field items picker.Entry[]
---@field matches table[]
---@field idx integer
---@field closed boolean
---@field view picker.View
local Picker = {}
Picker.__index = Picker
local active
local defaults = {
	opts = {
		preselect = true,
		bottom = true,
		shrink = true,
		promptprefix = '',
		prompt_title = true,
		pointer = '',
		marker = '│',
		infolist = { 'list' },
	},
	win = { height = 0.4, hidestatusline = false },
	mappings = {
		['<Down>'] = 'down',
		['<Up>'] = 'up',
		['<CR>'] = 'accept',
		['<Esc>'] = 'cancel',
		['<Tab>'] = 'mark',
		['<C-g>'] = 'togglelive',
		['<C-l>'] = 'togglepreview',
		['<C-q>'] = 'setqflist',
		['<C-s>'] = 'split',
		['<C-v>'] = 'vsplit',
		['<C-t>'] = 'tabnew',
	},
}
local config = {}

---@class picker.Entry
---@field id integer Original source index
---@field v any Original source value (never copied)
---@field text string Single-line display and search text
---@field icon? string
---@field icon_hl? string
---@field hls? table[] Byte ranges: { { start, end_exclusive }, highlight_group }

---@class picker.Options
---@field source table|fun(query: string, emit: fun(items: table?, err?: any), ctx: table): table|function|nil
---@field format_item? fun(item: any, index: integer): string
---@field on_choice? fun(item: any, index: integer, marked: table, picker: table)
---@field on_cancel? fun(picker: table)
---@field preview_item? fun(item: any, index: integer, picker: table): table? {buf, pos?, pos_end?}
---@field get_icon? fun(entry: picker.Entry): string?, string?
---@field hl_item? fun(entry: picker.Entry): table[]?
---@field to_quickfix? fun(item: any, index: integer): table
---@field sorter? fun(entries: picker.Entry[], query: string): table[] {index, character_positions, score}
---@field actions? table<string, fun(picker: table)>
---@field mappings? table<string, string|false>
---@field prompt? string
---@field defaulttext? string
---@field live? boolean Default: true for providers, false for lists
---@field debounce? integer Provider delay in milliseconds (default 30)
---@field opts? table Artio-style UI options
---@field win? table Artio-style window options

function M.setup(opts)
	config = vim.deepcopy(opts or {})
end

-- matchfuzzypos returns character offsets; the view converts them to byte ranges.
function M.sorter(entries, query)
	local pattern = query:match '^/([^/]*)/'
	if pattern then
		entries = vim.tbl_filter(function(entry)
			return entry.text:match(pattern) ~= nil
		end, entries)
		query = query:gsub('^/[^/]*/', '')
	end
	if query == '' then
		return vim.tbl_map(function(entry)
			return { entry.id, {}, 0 }
		end, entries)
	end
	local result = vim.fn.matchfuzzypos(entries, query, { key = 'text' })
	local matches = {}
	for i, entry in ipairs(result[1]) do
		matches[i] = { entry.id, result[2][i], result[3][i] }
	end
	return matches
end

function Picker:report(err)
	vim.schedule(function()
		vim.notify('picker: ' .. tostring(err), vim.log.levels.ERROR)
	end)
end

function Picker:fix()
	self.idx = math.min(#self.matches, math.max(self.opts.preselect and 1 or 0, self.idx))
end

function Picker:getcurrent(index)
	index = index or (self.matches[self.idx] and self.matches[self.idx][1])
	return index and self.items[index] or nil
end

-- Marked values stay in source order, including values hidden by fuzzy filtering.
function Picker:getmarked()
	local values = {}
	for _, entry in ipairs(self.items) do
		if self.marked[entry.id] then
			values[#values + 1] = entry.v
		end
	end
	return values
end

function Picker:filter()
	if self.closed then
		return
	end
	local ok, matches = pcall(self.live and function(entries)
		return vim.tbl_map(function(entry)
			return { entry.id, {}, 0 }
		end, entries)
	end or self.sorter, self.items, self.input)
	if not ok then
		self:report(matches)
		return
	end
	self.matches = matches
	self:fix()
	if self.view then
		self.view:trigger_show()
	end
end

function Picker:replace(items)
	assert(type(items) == 'table' and vim.islist(items), 'source must produce a list')
	local entries = {}
	for index, value in ipairs(items) do
		local text = self.format_item and self.format_item(value, index) or tostring(value)
		assert(type(text) == 'string', 'format_item must return a string')
		entries[index] = { id = index, v = value, text = vim.fn.strtrans(text) }
	end
	self.items, self.marked, self.idx = entries, {}, 0
	self:filter()
end

function Picker:invalidate()
	self.generation = self.generation + 1
	if self.pending_cancel then
		local cancel = self.pending_cancel
		self.pending_cancel = nil
		local ok, err = pcall(cancel)
		if not ok then
			self:report(err)
		end
	end
end

function Picker:refresh(immediate)
	if self.closed then
		return
	end
	self:invalidate()
	local generation = self.generation
	local query = self.live and self.liveinput or ''
	local function current()
		return not self.closed and self.generation == generation
	end
	local function emit(items, err)
		vim.schedule(function()
			if not current() then
				return
			end
			if err then
				self:report(err)
				return
			end
			local ok, result = pcall(self.replace, self, items)
			if not ok then
				self:report(result)
			end
		end)
	end
	local function request()
		if not current() then
			return
		end
		local ok, result = pcall(self.source, query, emit, {
			picker = self,
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
	-- Invalidate immediately so older results cannot arrive during the debounce interval.
	if immediate or self.debounce == 0 then
		request()
	else
		vim.defer_fn(request, self.debounce)
	end
end

function Picker:set_query(query)
	assert(type(query) == 'string', 'query must be a string')
	if self.closed then
		return
	end
	self.idx = 0
	if self.live then
		self.liveinput = query
		self.items, self.matches, self.marked = {}, {}, {}
		self:refresh()
	else
		self.input = query
		self:filter()
	end
	if self.view then
		self.view:trigger_show()
	end
end

function Picker:togglelive()
	if type(self.source) ~= 'function' then
		return
	end
	self:invalidate()
	self.live = not self.live
	self.input, self.idx = '', 0
	if self.live then
		self:refresh(true)
	else
		self:filter()
	end
	self.view:trigger_show()
end

function Picker:close()
	if self.closed then
		return
	end
	self.closed = true
	self:invalidate()
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

function Picker:cancel()
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

function Picker:accept()
	if self.closed then
		return
	end
	local entry = self:getcurrent()
	if not entry then
		return
	end
	local marked = self:getmarked()
	self:close()
	if self.on_choice then
		vim.schedule(function()
			self.on_choice(entry.v, entry.id, marked, self)
		end)
	end
end

function Picker:setqflist()
	if not self.to_quickfix then
		return
	end
	local selected = {}
	local has_marks = next(self.marked) ~= nil
	for _, entry in ipairs(self.items) do
		if has_marks and self.marked[entry.id] then
			selected[#selected + 1] = entry
		end
	end
	if not has_marks then
		for _, match in ipairs(self.matches) do
			selected[#selected + 1] = self.items[match[1]]
		end
	end
	local entries = vim.tbl_map(function(entry)
		return self.to_quickfix(entry.v, entry.id)
	end, selected)
	self:close()
	vim.schedule(function()
		vim.fn.setqflist({}, ' ', { title = self.prompt, items = entries })
		vim.cmd.copen()
	end)
end

function Picker:action(name)
	if self.closed then
		return
	end
	local ok, err = pcall(function()
		if self.actions[name] then
			self.actions[name](self)
		elseif name == 'down' or name == 'up' then
			self.idx = self.idx + (name == 'down' and 1 or -1)
			self:fix()
			self.view:trigger_show()
		elseif name == 'mark' then
			local entry = self:getcurrent()
			if entry then
				self.marked[entry.id] = not self.marked[entry.id] or nil
				self.view:trigger_show()
			end
		elseif name == 'togglepreview' then
			self.view:togglepreview()
		elseif name == 'accept' or name == 'cancel' or name == 'togglelive' or name == 'setqflist' then
			self[name](self)
		end
	end)
	if not ok then
		self:report(err)
	end
end

local function highlights()
	local normal = vim.api.nvim_get_hl(0, { name = 'Normal' })
	local msg = vim.api.nvim_get_hl(0, { name = 'MsgArea' })
	local cursor = vim.api.nvim_get_hl(0, { name = 'Cursor' })
	local cursorline = vim.api.nvim_get_hl(0, { name = 'CursorLine' })
	local groups = {
		PickerNormal = { fg = normal.fg, bg = msg.bg },
		PickerPrompt = { link = 'Title' },
		PickerSel = { fg = cursor.bg, bg = cursorline.bg },
		PickerPointer = { fg = cursor.bg },
		PickerMatch = { link = 'PmenuMatch' },
		PickerMark = { link = 'DiagnosticWarn' },
		PickerMarkLine = { link = 'Visual' },
	}
	for name, spec in pairs(groups) do
		spec.default = true
		vim.api.nvim_set_hl(0, name, spec)
	end
end

---@param options picker.Options
---@return table picker Handle: set_query, refresh, getcurrent, getmarked, action, accept, cancel
function M.pick(options)
	assert(type(options) == 'table', 'pick expects an options table')
	assert(
		type(options.source) == 'function' or (type(options.source) == 'table' and vim.islist(options.source)),
		'source must be a list or provider function'
	)
	assert(vim.fn.has 'nvim-0.12' == 1, 'picker requires Neovim >= 0.12 with ui2 enabled')
	local ui2 = require 'vim._core.ui2'
	assert(ui2.msg and ui2.cfg.enable, "enable require('vim._core.ui2').enable({}) before opening a picker")
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
	opts.prompttext = opts.opts.prompt_title and (opts.prompt .. ' ' .. opts.opts.promptprefix)
		or opts.opts.promptprefix
	opts.input = opts.live and '' or (opts.defaulttext or '')
	opts.liveinput = opts.live and (opts.defaulttext or '') or ''
	local self = setmetatable(opts, Picker)
	if type(self.source) == 'table' then
		self:replace(self.source)
	end
	if active then
		active:cancel()
	end
	active = self
	ui2.check_targets()
	highlights()
	self.buf = ui2.bufs.cmd
	self.keys, self.saved_maps = {}, {}
	self.view = require('picker.view'):new(self)
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
	return M.pick(options)
end

return M
