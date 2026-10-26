-- Run from the repository root: nvim --headless -u NONE -i NONE -l tests/better_select.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local ui2 = require 'vim._core.ui2'
-- vim._core.ui2.enable() does nothing without an attached UI, so initialize
-- its command-line and message modules directly for headless integration tests.
ui2.cmd = require 'vim._core.ui2.cmdline'
ui2.msg = require 'vim._core.ui2.messages'
ui2.check_targets()
local search = require 'better_select'
local failures = {}
local reported_errors = {}
vim.notify = function(message, level)
	if level == vim.log.levels.ERROR then
		reported_errors[#reported_errors + 1] = tostring(message)
	end
end
local handles = {}
local function open(opts)
	local handle = search.open(opts)
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
	if #reported_errors > 0 then
		ok, err = false, table.concat(reported_errors, '\n')
		reported_errors = {}
	end
	if ok then
		print('PASS: ' .. name)
	else
		failures[#failures + 1] = name .. ': ' .. tostring(err)
		print('FAIL: ' .. failures[#failures])
	end
end

test('initializes highlights once on first open and preserves colorscheme handling', function()
	assert(vim.fn.hlexists 'BetterSelectPrompt' == 0)
	local set_hl = vim.api.nvim_set_hl
	local calls = 0
	vim.api.nvim_set_hl = function(ns, name, spec)
		if name:match '^BetterSelect' then
			calls = calls + 1
		end
		return set_hl(ns, name, spec)
	end
	local ok, err = pcall(function()
		open({ source = { 'first' } }):close()
		assert(calls == 9)
		open({ source = { 'second' } }):close()
		assert(calls == 9)
	end)
	vim.api.nvim_set_hl = set_hl
	assert(ok, err)
	assert(#vim.api.nvim_get_autocmds {
		group = 'better_select.highlights',
		event = 'ColorScheme',
	} == 1)
	assert(vim.api.nvim_get_hl(0, { name = 'BetterSelectPrompt' }).link == 'Question')
	vim.cmd.colorscheme 'default'
	assert(vim.api.nvim_get_hl(0, { name = 'BetterSelectPrompt' }).link == 'Question')
	vim.api.nvim_set_hl(0, 'BetterSelectMark', { fg = 0x123456 })
	vim.api.nvim_exec_autocmds('ColorScheme', {})
	assert(vim.api.nvim_get_hl(0, { name = 'BetterSelectMark' }).fg == 0x123456)
	vim.api.nvim_set_hl(0, 'BetterSelectMark', { link = 'Special', default = true, force = true })
end)

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
	assert(#p.matches == 1 and p:get_current().v == b)
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
	p = search.select({ 'a' }, {}, function(v, i)
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

test('mode toggles preserve the query and render the same prompt text', function()
	local calls = {}
	local p = open {
		default_text = 'ap',
		source = function(query)
			calls[#calls + 1] = query
			return { 'apple', 'banana' }
		end,
	}
	local function assert_query(query)
		assert(p.query == query)
		local lines = vim.api.nvim_buf_get_lines(p.buf, 0, -1, false)
		assert(lines[#lines]:sub(-#query) == query, vim.inspect(lines))
	end
	flush()
	assert_query 'ap'
	assert(#p.matches == 2 and vim.deep_equal(calls, { 'ap' }))
	p:toggle_live()
	assert_query 'ap'
	assert(#calls == 1 and #p.matches == 1 and p:get_current().v == 'apple')
	p:set_query 'bn'
	assert_query 'bn'
	assert(#calls == 1 and #p.matches == 1 and p:get_current().v == 'banana')
	p:toggle_live()
	assert_query 'bn'
	flush()
	assert(vim.deep_equal(calls, { 'ap', 'bn' }) and #p.matches == 2)
	p:toggle_live()
	assert_query 'bn'
	assert(#p.matches == 1 and p:get_current().v == 'banana')
end)

test('local providers load the full source with an empty query and filter using the shared query', function()
	local calls = {}
	local p = open {
		live = false,
		default_text = 'bn',
		source = function(query)
			calls[#calls + 1] = query
			return { 'apple', 'banana' }
		end,
	}
	flush()
	assert(vim.deep_equal(calls, { '' }) and p.query == 'bn')
	assert(#p.matches == 1 and p:get_current().v == 'banana')
	p:set_query 'ap'
	assert(#calls == 1 and p.query == 'ap' and p:get_current().v == 'apple')
	p:refresh(true)
	flush()
	assert(vim.deep_equal(calls, { '', '' }) and p.query == 'ap')
	assert(#p.matches == 1 and p:get_current().v == 'apple')
	p:toggle_live()
	flush()
	assert(vim.deep_equal(calls, { '', '', 'ap' }) and p.query == 'ap')
end)

test('switching to local mode cancels pending live work and ignores late results', function()
	local emits, contexts, calls = {}, {}, {}
	local cancellations = 0
	local p = open {
		debounce = 0,
		source = function(query, emit, ctx)
			calls[#calls + 1] = query
			emits[#emits + 1], contexts[#contexts + 1] = emit, ctx
			return function()
				cancellations = cancellations + 1
			end
		end,
	}
	emits[1] { 'apple', 'banana' }
	flush()
	p:set_query 'bn'
	p:toggle_live()
	assert(not p.live and p.query == 'bn' and contexts[2].cancelled())
	assert(cancellations == 2)
	emits[2] { 'stale' }
	flush()
	assert(#p.items == 0)
	p:refresh(true)
	assert(vim.deep_equal(calls, { '', 'bn', '' }))
	emits[3] { 'apple', 'banana' }
	flush()
	assert(p.query == 'bn' and #p.matches == 1 and p:get_current().v == 'banana')
	p:toggle_live()
	assert(calls[4] == 'bn' and p.query == 'bn')
	emits[4] { 'banana' }
	flush()
	assert(#p.matches == 1 and p:get_current().v == 'banana')
end)

test('pattern filtering and multibyte match highlights use whole characters', function()
	local p = open { source = { 'é猫', 'banana' } }
	p:set_query '/^é/猫'
	assert(#p.matches == 1)
	local marks = vim.api.nvim_buf_get_extmarks(
		ui2.bufs.cmd,
		vim.api.nvim_create_namespace '@better_select.view.ns',
		0,
		-1,
		{ details = true }
	)
	local found = false
	for _, mark in ipairs(marks) do
		if mark[4].hl_group == 'BetterSelectMatchSel' then
			assert(mark[4].end_col - mark[3] == 3, vim.inspect(mark))
			found = true
		end
	end
	assert(found, vim.inspect(marks))
end)

test('preview without a position works and closes with the search', function()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'preview' })
	local p = open {
		source = { 'a' },
		preview_item = function()
			return { buf = buf }
		end,
	}
	p:action 'toggle_preview'
	local preview = p.view.preview_win
	assert(preview and vim.api.nvim_win_is_valid(preview))
	p:cancel()
	assert(not vim.api.nvim_win_is_valid(preview))
	assert(vim.api.nvim_buf_is_valid(buf)) -- caller owns preview buffers
	vim.api.nvim_buf_delete(buf, { force = true })
end)

test('replacing a search restores ui2 before the next opens', function()
	local cancellations = 0
	local p = open {
		source = { 'old' },
		on_cancel = function()
			cancellations = cancellations + 1
		end,
	}
	local next_search = open { source = { 'new' } }
	flush()
	assert(p.closed and not next_search.closed and cancellations == 1)
	assert(vim.api.nvim_buf_get_lines(ui2.bufs.cmd, 0, 1, false)[1]:find('new', 1, true))
end)

test('custom actions expose Plug mappings without assigning physical keys', function()
	local received
	local p = open {
		source = { 'a' },
		actions = {
			custom = function(handle)
				received = handle
			end,
		},
	}
	p:action 'custom'
	assert(received == p)
	assert(vim.fn.maparg('<Tab>', 'i', false, true).buffer ~= 1)
	local mapping = vim.fn.maparg('<Plug>(acme-better-select-custom)', 'i', false, true)
	mapping.callback()
	assert(received == p)
end)

test('central picker bindings preserve global maps and reject local conflicts', function()
	require 'keymaps'
	local global = function() end
	vim.keymap.set('i', '<Tab>', global)
	local p = open { source = { 'a' } }
	assert(vim.fn.maparg('<Tab>', 'i') == '<Plug>(acme-better-select-mark)')
	p:close()
	assert(vim.fn.maparg('<Tab>', 'i', false, true).callback == global)
	local local_callback = function() end
	vim.keymap.set('i', '<Tab>', local_callback, { buffer = ui2.bufs.cmd })
	local ok = pcall(open, { source = { 'a' } })
	assert(not ok)
	assert(search.current() == nil)
	vim.api.nvim_buf_call(ui2.bufs.cmd, function()
		assert(vim.fn.maparg('<Tab>', 'i', false, true).callback == local_callback)
		assert(vim.fn.maparg('<Plug>(acme-better-select-mark)', 'i') == '')
	end)
	vim.keymap.del('i', '<Tab>', { buffer = ui2.bufs.cmd })
	vim.keymap.del('i', '<Tab>')
end)

test('top prompt, fixed height, no preselection, scrolling and default text', function()
	local p = open {
		source = { 'a1', 'a2', 'a3', 'a4', 'a5' },
		default_text = 'a',
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
	assert(p:get_current().v == 'a5')
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
	p:set_quickfix()
	flush()
	assert(p.closed)
	local entries = vim.fn.getqflist()
	assert(#entries == 1 and entries[1].text == 'apple')
	vim.cmd.cclose()
end)

test('icons, custom highlights and marks survive redraw without duplicate extmarks', function()
	local icon_calls, highlight_calls = 0, 0
	local p = open {
		source = { 'é猫', 'other' },
		get_icon = function()
			icon_calls = icon_calls + 1
			return '猫', 'Special'
		end,
		hl_item = function()
			highlight_calls = highlight_calls + 1
			return { { { 0, 2 }, 'Title' } }
		end,
	}
	p:set_query 'é'
	p:action 'mark'
	local ns = vim.api.nvim_create_namespace '@better_select.view.ns'
	local function marks()
		return vim.api.nvim_buf_get_extmarks(p.buf, ns, 0, -1, { details = true })
	end
	local before = #marks()
	p:action 'up'
	assert(#marks() == before and icon_calls == 2 and highlight_calls == 2)
	local groups = {}
	for _, mark in ipairs(marks()) do
		local details = mark[4]
		groups[details.hl_group or ''] = true
		if details.hl_group == 'Title' then
			assert(mark[3] == 7 and details.end_col == 9, vim.inspect(mark))
		end
	end
	assert(groups.Special and groups.Title and groups.BetterSelectMarkLine and groups.BetterSelectMatchSel)
	assert(vim.api.nvim_buf_get_lines(p.buf, 0, 1, false)[1] == '  猫  é猫')
end)

test('prompt edits update filtering and keep the cursor outside the prefix', function()
	local p = open { source = { 'apple', 'banana' }, prompt = 'Fruit' }
	local row = p.view.prompt_row
	local prefix = p.view.prompt_length
	local line = vim.api.nvim_buf_get_lines(p.buf, row, row + 1, false)[1]
	vim.api.nvim_buf_set_lines(p.buf, row, row + 1, false, { line:sub(1, prefix) .. 'bn' })
	vim.api.nvim_exec_autocmds('TextChangedI', { buffer = p.buf })
	assert(p.query == 'bn' and p:get_current().v == 'banana')
	vim.api.nvim_win_set_cursor(ui2.wins.cmd, { p.view.prompt_row + 1, 0 })
	vim.api.nvim_exec_autocmds('CursorMovedI', { buffer = p.buf })
	assert(vim.api.nvim_win_get_cursor(ui2.wins.cmd)[2] >= prefix)
end)

test('replacement searches start with a fresh scroll position', function()
	local p = open { source = { 'one', 'two', 'three', 'four' }, win = { height = 2 } }
	for _ = 1, 3 do
		p:action 'down'
	end
	assert(p.view.offset == 3)
	local next_search = open { source = { 'first', 'second' }, win = { height = 2 } }
	assert(next_search.view.offset == 0 and next_search:get_current().v == 'first')
	assert(vim.api.nvim_buf_get_lines(next_search.buf, 0, 1, false)[1]:find('first', 1, true))
end)

test('fractional layout resizes while keeping the selected item visible', function()
	local lines = vim.o.lines
	local p = open {
		source = vim.fn.range(1, 40),
		win = { height = 0.5 },
		opts = { bottom = false, shrink = false },
	}
	for _ = 1, 30 do
		p:action 'down'
	end
	local value = p:get_current().v
	local ok, err = pcall(function()
		vim.o.lines = lines - 4
		vim.api.nvim_exec_autocmds('VimResized', {})
		local rendered = vim.api.nvim_buf_get_lines(p.buf, 0, -1, false)
		assert(#rendered == math.ceil(vim.o.lines * 0.5))
		assert(p:get_current().v == value)
		assert(vim.tbl_contains(rendered, '  ' .. value), vim.inspect(rendered))
	end)
	vim.o.lines = lines
	assert(ok, err)
end)

test('hidden statusline keeps the command list visible and restores its configuration', function()
	local height = vim.o.cmdheight
	local config = vim.api.nvim_win_get_config(ui2.wins.cmd)
	local p = open { source = { 'a', 'b' }, win = { height = 4, hide_statusline = true } }
	assert(vim.o.cmdheight == 0)
	assert(not vim.api.nvim_win_get_config(ui2.wins.cmd).hide)
	assert(vim.api.nvim_win_get_height(ui2.wins.cmd) == 3)
	p:close()
	local restored = vim.api.nvim_win_get_config(ui2.wins.cmd)
	assert(vim.o.cmdheight == height and restored.height == config.height and restored.hide == config.hide)
end)

test('preview follows selection, updates options and closes when the caller has no content', function()
	local a, b = vim.api.nvim_create_buf(false, true), vim.api.nvim_create_buf(false, true)
	for _, buf in ipairs { a, b } do
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'first', 'second' })
	end
	local p = open {
		source = { a, b, false },
		preview_item = function(buf)
			return buf and { buf = buf, pos = { 2, 0 }, pos_end = { 2, 1 } } or nil
		end,
		win = {
			height = 4,
			preview_opts = function(view)
				assert(view.search and view.win.height == 4)
				return { width = 30, height = 2, border = 'none' }
			end,
		},
	}
	p:action 'toggle_preview'
	local preview = p.view.preview_win
	assert(vim.api.nvim_win_get_buf(preview) == a and vim.wo[preview].cursorline)
	assert(vim.deep_equal(vim.api.nvim_win_get_cursor(preview), { 2, 0 }))
	p:action 'down'
	assert(vim.api.nvim_win_get_buf(preview) == b)
	assert(vim.api.nvim_win_get_width(preview) == 30 and vim.api.nvim_win_get_height(preview) == 2)
	p:action 'down'
	assert(not vim.api.nvim_win_is_valid(preview))
	p:close()
	vim.api.nvim_buf_delete(a, { force = true })
	vim.api.nvim_buf_delete(b, { force = true })
end)

test('failed opening restores the editor and allows a subsequent search', function()
	local win, height, showmode = vim.api.nvim_get_current_win(), vim.o.cmdheight, vim.o.showmode
	local filetype, buftype = vim.bo[ui2.bufs.cmd].filetype, vim.bo[ui2.bufs.cmd].buftype
	local ok, err = pcall(search.open, {
		source = { 'a' },
		get_icon = function()
			error 'broken icon provider'
		end,
	})
	assert(not ok and tostring(err):find('broken icon provider', 1, true))
	assert(vim.api.nvim_get_current_win() == win and vim.o.cmdheight == height and vim.o.showmode == showmode)
	assert(vim.bo[ui2.bufs.cmd].filetype == filetype and vim.bo[ui2.bufs.cmd].buftype == buftype)
	assert(open({ source = { 'next' } }):get_current().v == 'next')
end)

test('accept filters prompt edits even before TextChangedI runs', function()
	local selected
	local p = open {
		source = { 'alpha', 'beta' },
		on_choice = function(value)
			selected = value
		end,
	}
	local row = p.view.prompt_row
	local line = vim.api.nvim_buf_get_lines(p.buf, row, row + 1, false)[1]
	vim.api.nvim_buf_set_lines(p.buf, row, row + 1, false, { line:sub(1, p.view.prompt_length) .. 'beta' })
	p:accept()
	flush()
	assert(selected == 'beta')
end)

if #failures > 0 then
	error(table.concat(failures, '\n'))
end
