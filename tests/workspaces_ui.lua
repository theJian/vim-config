-- Run with an attached terminal: nvim -u NONE -i NONE -c 'luafile tests/workspaces_ui.lua'
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.g.mapleader = ' '
vim.o.hidden, vim.o.swapfile = true, false
require('vim._core.ui2').enable {}
local api = vim.api
local temp = vim.fn.tempname()
vim.fn.mkdir(temp .. '/alpha', 'p')
vim.fn.mkdir(temp .. '/beta', 'p')
temp = vim.uv.fs_realpath(temp)
vim.fn.writefile({ 'alpha one', 'alpha two' }, temp .. '/alpha/a.lua')
vim.fn.writefile({ 'beta' }, temp .. '/beta/b.lua')
local store = require 'workspace_store'
store.directory = function()
	return temp .. '/state'
end
local w, p = require 'workspaces', require 'projects'
w.setup()
p.setup()
p.add(temp .. '/alpha')
p.add(temp .. '/beta')
local picker = require 'better_select'
local active
local open = picker.open
picker.open = function(opts)
	active = open(opts)
	return active
end
local alpha, alpha_win
local steps = {
	function()
		api.nvim_input ' pp'
	end,
	function()
		assert(active.prompt == 'Projects' and api.nvim_get_mode().mode == 'i')
		api.nvim_input 'alpha<CR>'
	end,
	function()
		assert(active.prompt == 'Project files' and #active.items == 1)
		api.nvim_input 'a.lua<CR>'
	end,
	function()
		assert(api.nvim_buf_get_name(0) == temp .. '/alpha/a.lua')
		alpha = api.nvim_get_current_tabpage()
		api.nvim_win_set_cursor(0, { 2, 2 })
		vim.cmd.vsplit()
		alpha_win = api.nvim_get_current_win()
		api.nvim_input ' pp'
	end,
	function()
		assert(
			active.prompt == 'Projects' and not active.closed and api.nvim_get_mode().mode == 'i',
			vim.inspect { prompt = active.prompt, closed = active.closed, mode = api.nvim_get_mode() }
		)
		api.nvim_input 'beta<CR>'
	end,
	function()
		assert(
			active.prompt == 'Project files',
			vim.inspect {
				prompt = active.prompt,
				closed = active.closed,
				query = active.query,
				mode = api.nvim_get_mode(),
			}
		)
		api.nvim_input 'b.lua<CR>'
	end,
	function()
		assert(api.nvim_buf_get_name(0) == temp .. '/beta/b.lua')
		assert(api.nvim_get_current_tabpage() ~= alpha)
		api.nvim_input ' <Tab>.'
	end,
	function()
		assert(active.prompt == 'Workspaces')
		api.nvim_input 'alpha<CR>'
	end,
	function()
		assert(api.nvim_get_current_tabpage() == alpha)
		assert(api.nvim_get_current_win() == alpha_win)
		assert(vim.deep_equal(api.nvim_win_get_cursor(0), { 2, 2 }), vim.inspect(api.nvim_win_get_cursor(0)))
		api.nvim_input ' <Tab>`'
	end,
	function()
		assert(w.current().name == 'beta')
		api.nvim_input ' <Tab>2'
	end,
	function()
		assert(api.nvim_get_current_tabpage() == alpha)
		api.nvim_input ' pp'
	end,
	function()
		api.nvim_input '<Esc>'
	end,
	function()
		assert(active.closed and api.nvim_get_current_win() == alpha_win)
		assert(api.nvim_get_mode().mode == 'n')
	end,
}
local function finish(ok, err)
	if active then
		active:close()
	end
	api.nvim_del_augroup_by_name 'NativeWorkspaces'
	api.nvim_del_augroup_by_name 'NativeProjects'
	vim.fn.delete(temp, 'rf')
	local result = ok and 'PASS keyboard project/workspace pickers, file selection, layout restoration and cancellation'
		or 'FAIL ' .. tostring(err)
	if vim.env.WORKSPACES_TEST_RESULT then
		vim.fn.writefile({ result }, vim.env.WORKSPACES_TEST_RESULT)
	end
	print(result)
	vim.cmd(ok and 'qa!' or 'cquit')
end
local function step(i)
	local ok, err = pcall(steps[i])
	if not ok or i == #steps then
		finish(ok, err)
	else
		vim.defer_fn(function()
			step(i + 1)
		end, 200)
	end
end
vim.defer_fn(function()
	step(1)
end, 200)
