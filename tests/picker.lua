-- Run: nvim --headless -u NONE -i NONE -l tests/picker.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local ui2 = require 'vim._core.ui2'
-- enable() intentionally does nothing without an attached UI. Use its real
-- windows and modules for headless integration tests.
ui2.cmd = require 'vim._core.ui2.cmdline'
ui2.msg = require 'vim._core.ui2.messages'
ui2.check_targets()
local picker = require 'picker'
local failures = {}
local handles = {}
local function open(opts)
	local handle = picker.pick(opts)
	handles[#handles + 1] = handle
	return handle
end
local function flush()
	vim.wait(50, function()
		return false
	end, 1)
end
local function test(name, callback)
	local ok, err = pcall(callback)
	for _, handle in ipairs(handles) do
		handle:close()
	end
	handles = {}
	flush()
	if ok then
		print('PASS: ' .. name)
	else
		failures[#failures + 1] = name .. ': ' .. tostring(err)
		print('FAIL: ' .. failures[#failures])
	end
end

test('renders immediately and restores ui2 options, cursor, mappings and height', function()
	local win = vim.api.nvim_get_current_win()
	local height, showmode = vim.o.cmdheight, vim.o.showmode
	local filetype, buftype = vim.bo[ui2.bufs.cmd].filetype, vim.bo[ui2.bufs.cmd].buftype
	local old_callback = function() end
	vim.keymap.set('i', '<Tab>', old_callback, { buffer = ui2.bufs.cmd, desc = 'existing' })
	local p = open { source = { 'apple', 'apricot', 'banana' }, prompt = 'fruit', win = { height = 4 } }
	assert(#p.matches == 3 and p.idx == 1)
	local lines = vim.api.nvim_buf_get_lines(ui2.bufs.cmd, 0, -1, false)
	assert(lines[1]:find('apple', 1, true) and lines[4]:find('fruit', 1, true), vim.inspect(lines))
	p:cancel()
	assert(vim.api.nvim_get_current_win() == win)
	assert(vim.o.cmdheight == height and vim.o.showmode == showmode)
	assert(vim.bo[ui2.bufs.cmd].filetype == filetype and vim.bo[ui2.bufs.cmd].buftype == buftype)
	assert(vim.fn.maparg('<Tab>', 'i', false, true).buffer ~= 1) -- original window has no local map
	vim.api.nvim_buf_call(ui2.bufs.cmd, function()
		assert(vim.fn.maparg('<Tab>', 'i', false, true).callback == old_callback)
	end)
	vim.keymap.del('i', '<Tab>', { buffer = ui2.bufs.cmd })
end)

test('returns original object identity and source index after fuzzy filtering', function()
	local a, b = { name = 'apple' }, { name = 'banana' }
	local chosen, index
	local p = open {
		source = { a, b },
		format_item = function(item)
			return item.name
		end,
		on_choice = function(item, idx)
			chosen, index = item, idx
		end,
	}
	p:set_query 'bn'
	assert(#p.matches == 1 and p:getcurrent().v == b)
	p:accept()
	flush()
	assert(chosen == b and index == 2)
end)

test('keeps equal score order, marks hidden values, and accepts false', function()
	local selected, marks
	local p = open {
		source = { false, 'two', 'three' },
		on_choice = function(value, _, marked)
			selected, marks = value, marked
		end,
	}
	assert(p.matches[1][1] == 1 and p.matches[2][1] == 2)
	p:action 'mark'
	p:action 'down'
	p:action 'mark'
	p:set_query 'false'
	p:accept()
	flush()
	assert(selected == false and marks[1] == false and marks[2] == 'two')
end)

test('cancellation and empty acceptance have correct callback counts', function()
	local count = 0
	local p = open {
		source = {},
		on_cancel = function()
			count = count + 1
		end,
	}
	p:accept()
	assert(not p.closed)
	p:cancel()
	p:cancel()
	flush()
	assert(count == 1)
	local value, index = true, true
	p = picker.select({ 'a' }, {}, function(v, i)
		value, index = v, i
	end)
	p:cancel()
	flush()
	assert(value == nil and index == nil)
end)

test('provider debounces and drops stale results after query changes and closure', function()
	local emits, calls, cancellations = {}, {}, 0
	local p = open {
		debounce = 10,
		source = function(query, emit, ctx)
			calls[#calls + 1] = query
			emits[query] = { emit = emit, ctx = ctx }
			return function()
				cancellations = cancellations + 1
			end
		end,
	}
	p:set_query 'a'
	p:set_query 'ab'
	flush()
	assert(vim.deep_equal(calls, { '', 'ab' }), vim.inspect(calls))
	emits[''].emit { 'stale' }
	emits.ab.emit { 'latest' }
	flush()
	assert(p.items[1].v == 'latest' and emits[''].ctx.cancelled())
	p:cancel()
	emits.ab.emit { 'closed' }
	flush()
	assert(p.items[1].v == 'latest' and cancellations == 2)
end)

test('synchronous provider and live/fuzzy toggle use separate queries', function()
	local calls = 0
	local p = open {
		source = function()
			calls = calls + 1
			return { 'apple', 'banana' }
		end,
	}
	flush()
	assert(#p.matches == 2)
	p:togglelive()
	p:set_query 'bn'
	assert(calls == 1 and #p.matches == 1 and p:getcurrent().v == 'banana')
	p:togglelive()
	flush()
	assert(calls == 2 and #p.matches == 2)
end)

test('pattern filtering and multibyte match highlights use whole characters', function()
	local p = open { source = { 'é猫', 'banana' } }
	p:set_query '/^é/猫'
	assert(#p.matches == 1)
	local marks = vim.api.nvim_buf_get_extmarks(
		ui2.bufs.cmd,
		vim.api.nvim_create_namespace '@picker.view.ns',
		0,
		-1,
		{ details = true }
	)
	local found = false
	for _, mark in ipairs(marks) do
		if mark[4].hl_group == 'PickerMatch' then
			assert(mark[4].end_col - mark[3] == 3, vim.inspect(mark))
			found = true
		end
	end
	assert(found, vim.inspect(marks))
end)

test('preview without a position works and closes with the picker', function()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'preview' })
	local p = open {
		source = { 'a' },
		preview_item = function()
			return { buf = buf }
		end,
	}
	p:action 'togglepreview'
	local preview = p.view.preview_win
	assert(preview and vim.api.nvim_win_is_valid(preview))
	p:cancel()
	assert(not vim.api.nvim_win_is_valid(preview))
	assert(vim.api.nvim_buf_is_valid(buf)) -- caller owns preview buffers
	vim.api.nvim_buf_delete(buf, { force = true })
end)

test('replacing a picker restores ui2 before the next opens', function()
	local cancellations = 0
	local p = open {
		source = { 'old' },
		on_cancel = function()
			cancellations = cancellations + 1
		end,
	}
	local next_picker = open { source = { 'new' } }
	flush()
	assert(p.closed and not next_picker.closed and cancellations == 1)
	assert(vim.api.nvim_buf_get_lines(ui2.bufs.cmd, 0, 1, false)[1]:find('new', 1, true))
end)

test('custom actions receive the handle and disabled mappings are omitted', function()
	local received
	local p = open {
		source = { 'a' },
		mappings = { ['<Tab>'] = false, ['<C-x>'] = 'custom' },
		actions = {
			custom = function(handle)
				received = handle
			end,
		},
	}
	p:action 'custom'
	assert(received == p)
	assert(vim.fn.maparg('<Tab>', 'i', false, true).buffer ~= 1)
	local mapping = vim.fn.maparg('<C-x>', 'i', false, true)
	mapping.callback()
	assert(received == p)
end)

test('top prompt, fixed height, no preselection, scrolling and default text', function()
	local p = open {
		source = { 'a1', 'a2', 'a3', 'a4', 'a5' },
		defaulttext = 'a',
		opts = { bottom = false, shrink = false, preselect = false },
		win = { height = 3 },
	}
	assert(p.idx == 0)
	local lines = vim.api.nvim_buf_get_lines(p.buf, 0, -1, false)
	assert(#lines == 3 and lines[1]:sub(-1) == 'a')
	assert(vim.api.nvim_win_get_cursor(0)[2] == #lines[1])
	for _ = 1, 5 do
		p:action 'down'
	end
	assert(p:getcurrent().v == 'a5')
	lines = vim.api.nvim_buf_get_lines(p.buf, 0, -1, false)
	assert(lines[3]:find('a5', 1, true))
	p:set_query 'missing'
	assert(#p.matches == 0 and p.idx == 0)
	assert(#vim.api.nvim_buf_get_lines(p.buf, 0, -1, false) == 3)
end)

test('quickfix converts marked original values including hidden matches', function()
	local p = open {
		source = { 'apple', 'banana', 'apricot' },
		prompt = 'fruit',
		to_quickfix = function(value, index)
			return { text = value, lnum = index }
		end,
	}
	p:action 'mark'
	p:action 'down'
	p:action 'mark'
	p:action 'mark'
	p:set_query 'banana'
	p:setqflist()
	flush()
	assert(p.closed)
	local entries = vim.fn.getqflist()
	assert(#entries == 1 and entries[1].text == 'apple')
	vim.cmd.cclose()
end)

if #failures > 0 then
	error(table.concat(failures, '\n'))
end
