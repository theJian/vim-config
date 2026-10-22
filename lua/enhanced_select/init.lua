-- Enhanced select using ui2. Licensed under EUPL-1.2; see LICENSE and NOTICE in this directory.
local M = {}
---@class enhanced_select.EnhancedSelect: enhanced_select.Options
---@field items enhanced_select.Entry[]
---@field matches table[] Ordered {source_index, zero_based_character_positions, score} matches
---@field idx integer 1-based match position; 0 means no selection
---@field closed boolean
---@field view enhanced_select.View
local EnhancedSelect = {}
EnhancedSelect.__index = EnhancedSelect
local active
local defaults = {
	opts = {
		preselect = true,
		bottom = true,
		shrink = true,
		prompt_prefix = '',
		prompt_title = true,
		pointer = '',
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

---@alias enhanced_select.Highlight {[1]: {[1]: integer, [2]: integer}, [2]: string} Byte range {start, end_exclusive} and highlight group

---@class enhanced_select.Entry
---@field id integer 1-based original source index
---@field v any Original source value (never copied)
---@field text string Single-line display and search text
---@field icon? string
---@field icon_hl? string
---@field hls? enhanced_select.Highlight[] Byte ranges relative to the formatted label

---@class enhanced_select.Options
---@field source table|fun(query: string, emit: fun(items: table?, err?: any), ctx: table): table|function|nil
---@field format_item? fun(item: any, index: integer): string
---@field on_choice? fun(item: any, index: integer, marked: table, search: table)
---@field on_cancel? fun(search: table)
---@field preview_item? fun(item: any, index: integer, search: table): table? {buf, pos?, pos_end?}
---@field get_icon? fun(entry: enhanced_select.Entry): string?, string?
---@field hl_item? fun(entry: enhanced_select.Entry): table[]?
---@field to_quickfix? fun(item: any, index: integer): table
---@field sorter? fun(entries: enhanced_select.Entry[], query: string): table[] {index, character_positions, score}
---@field actions? table<string, fun(search: table)>
---@field mappings? table<string, string|false>
---@field prompt? string
---@field default_text? string
---@field live? boolean Default: true for providers, false for lists
---@field debounce? integer Provider delay in milliseconds (default 30)
---@field opts? table Prompt, selection, marking, and match-count display options
---@field win? table EnhancedSelect height, statusline visibility, and preview-window options

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

function EnhancedSelect:report(err)
	vim.schedule(function()
		vim.notify('search: ' .. tostring(err), vim.log.levels.ERROR)
	end)
end

function EnhancedSelect:clamp()
	self.idx = math.min(#self.matches, math.max(self.opts.preselect and 1 or 0, self.idx))
end

function EnhancedSelect:get_current(index)
	index = index or (self.matches[self.idx] and self.matches[self.idx][1])
	return index and self.items[index] or nil
end

-- Marked values stay in source order, including values hidden by fuzzy filtering.
function EnhancedSelect:get_marked()
	return vim.iter(self.items)
		:filter(function(entry)
			return self.marked[entry.id]
		end)
		:map(function(entry)
			return entry.v
		end)
		:totable()
end

function EnhancedSelect:filter()
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
	self:clamp()
	if self.view then
		self.view:trigger_show()
	end
end

function EnhancedSelect:replace(items)
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

function EnhancedSelect:invalidate()
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

function EnhancedSelect:refresh(immediate)
	if self.closed then
		return
	end
	self:invalidate()
	local generation = self.generation
	local query = self.live and self.live_input or ''
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

function EnhancedSelect:set_query(query)
	assert(type(query) == 'string', 'query must be a string')
	if self.closed then
		return
	end
	self.idx = 0
	if self.live then
		self.live_input = query
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

function EnhancedSelect:toggle_live()
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

function EnhancedSelect:close()
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

function EnhancedSelect:cancel()
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

function EnhancedSelect:accept()
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

function EnhancedSelect:set_quickfix()
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

function EnhancedSelect:action(name)
	if self.closed then
		return
	end
	local ok, err = pcall(function()
		if self.actions[name] then
			self.actions[name](self)
		elseif name == 'down' or name == 'up' then
			self.idx = self.idx + (name == 'down' and 1 or -1)
			self:clamp()
			self.view:trigger_show()
		elseif name == 'mark' then
			local entry = self:get_current()
			if entry then
				self.marked[entry.id] = not self.marked[entry.id] or nil
				self.view:trigger_show()
			end
		elseif name == 'toggle_preview' then
			self.view:toggle_preview()
		elseif name == 'accept' or name == 'cancel' or name == 'toggle_live' or name == 'set_quickfix' then
			self[name](self)
		end
	end)
	if not ok then
		self:report(err)
	end
end

local function highlights()
	local groups = {
		EnhancedSelectNormal = { link = 'Pmenu' },
		EnhancedSelectPrompt = { link = 'Question' },
		EnhancedSelectSel = { link = 'PmenuSel' },
		EnhancedSelectPointer = { link = 'PmenuSel' },
		EnhancedSelectMatch = { link = 'PmenuMatch' },
		EnhancedSelectMatchSel = { link = 'PmenuMatchSel' },
		EnhancedSelectInfo = { link = 'PmenuExtra' },
		EnhancedSelectMark = { link = 'Special' },
		EnhancedSelectMarkLine = { link = 'Visual' },
	}
	for name, spec in pairs(groups) do
		spec.default = true
		vim.api.nvim_set_hl(0, name, spec)
	end
end

highlights()
vim.api.nvim_create_autocmd('ColorScheme', {
	group = vim.api.nvim_create_augroup('enhanced_select.highlights', { clear = true }),
	callback = highlights,
})

---@param options enhanced_select.Options
---@return table search Handle: set_query, refresh, get_current, get_marked, action, accept, cancel
function M.open(options)
	assert(type(options) == 'table', 'open expects an options table')
	assert(
		type(options.source) == 'function' or (type(options.source) == 'table' and vim.islist(options.source)),
		'source must be a list or provider function'
	)
	assert(vim.fn.has 'nvim-0.12' == 1, 'search requires Neovim >= 0.12 with ui2 enabled')
	local ui2 = require 'vim._core.ui2'
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
	opts.input = opts.live and '' or (opts.default_text or '')
	opts.live_input = opts.live and (opts.default_text or '') or ''
	local self = setmetatable(opts, EnhancedSelect)
	if type(self.source) == 'table' then
		self:replace(self.source)
	end
	if active then
		active:cancel()
	end
	active = self
	ui2.check_targets()
	self.buf = ui2.bufs.cmd
	self.keys, self.saved_maps = {}, {}
	self.view = require('enhanced_select.view'):new(self)
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
