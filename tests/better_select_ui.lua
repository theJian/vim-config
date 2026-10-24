-- Run in a terminal: nvim -u NONE -i NONE -c 'luafile tests/better_select_ui.lua'
vim.opt.rtp:prepend(vim.fn.getcwd())
require('vim._core.ui2').enable {}
local search = require 'better_select'
local original_win, original_height = vim.api.nvim_get_current_win(), vim.o.cmdheight
local picker, chosen, marked
local steps = {}
for _, bottom in ipairs { true, false } do
	steps[#steps + 1] = function()
		chosen, marked = nil, nil
		picker = search.open {
			source = { 'banana', 'apple', 'apricot' },
			prompt = 'Fruit',
			opts = { bottom = bottom, shrink = bottom },
			win = { height = 4 },
			on_choice = function(value, _, marks)
				chosen, marked = value, marks
			end,
		}
	end
	steps[#steps + 1] = function()
		assert(vim.api.nvim_get_mode().mode == 'i')
		vim.api.nvim_input 'ap'
	end
	steps[#steps + 1] = function()
		assert(picker.query == 'ap' and #picker.matches == 2, picker.query)
		assert(picker:get_current().v == 'apple')
		vim.api.nvim_input '<Left>x'
	end
	steps[#steps + 1] = function()
		assert(picker.query == 'axp' and #picker.matches == 0, picker.query)
		vim.api.nvim_input '<BS><End>'
	end
	steps[#steps + 1] = function()
		assert(picker.query == 'ap' and #picker.matches == 2, picker.query)
		vim.api.nvim_input '<Tab><Down><CR>'
	end
	steps[#steps + 1] = function()
		assert(chosen == 'apricot', vim.inspect(chosen))
		assert(vim.deep_equal(marked, { 'apple' }), vim.inspect(marked))
		assert(picker.closed and vim.api.nvim_get_current_win() == original_win)
		assert(vim.o.cmdheight == original_height)
	end
end
local function finish(ok, err)
	if picker then
		pcall(picker.close, picker)
	end
	local message = ok and 'PASS: attached UI typing, editing, marking and acceptance in both layouts'
		or ('FAIL: ' .. tostring(err))
	if vim.env.BETTER_SELECT_TEST_RESULT then
		vim.fn.writefile({ message }, vim.env.BETTER_SELECT_TEST_RESULT)
	end
	io.stdout:write(message .. '\n')
	vim.cmd(ok and 'qa!' or 'cquit')
end
local function run_step(index)
	local ok, err = pcall(steps[index])
	if not ok or index == #steps then
		finish(ok, err)
	else
		vim.defer_fn(function()
			run_step(index + 1)
		end, 100)
	end
end
vim.defer_fn(function()
	run_step(1)
end, 100)
