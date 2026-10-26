-- nvim --headless -u NONE -i NONE -l tests/workspaces_review.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.g.mapleader = ' '
vim.o.hidden, vim.o.swapfile = true, false
vim.o.shell, vim.o.shellcmdflag = '/bin/sh', '-c'
local api = vim.api
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, 'p')
temp = vim.uv.fs_realpath(temp)
local store = require 'workspace_store'
store.directory = function()
	return temp .. '/state'
end
local ui2 = require 'vim._core.ui2'
ui2.cmd, ui2.msg = require 'vim._core.ui2.cmdline', require 'vim._core.ui2.messages'
ui2.check_targets()
local picker = require 'better_select'
local active, original_open = nil, picker.open
picker.open = function(options)
	active = original_open(options)
	return active
end
local w, p = require 'workspaces', require 'projects'
w.setup()
p.setup()
local errors = {}
local function file(name, lines)
	vim.fn.mkdir(vim.fs.dirname(name), 'p')
	vim.fn.writefile(lines or { 'original' }, name)
end
local root, other = temp .. '/project', temp .. '/other'
file(root .. '/.projectile', {})
file(root .. '/file.txt')
file(other .. '/.projectile', {})
file(other .. '/other.txt')
local function test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if active then
		active:close()
	end
	for _, buf in ipairs(api.nvim_list_bufs()) do
		vim.bo[buf].modified = false
	end
	pcall(w.clear)
	vim.wait(20, function()
		return false
	end)
	print((ok and 'PASS ' or 'FAIL ') .. name)
	if not ok then
		errors[#errors + 1] = name .. ': ' .. err
	end
end

test('empty exits preserve the previous recoverable session', function()
	store.write('last-session', { sentinel = true })
	assert(w.save_session() == false)
	assert(store.read('last-session').sentinel)
	vim.cmd.edit(vim.fn.fnameescape(root .. '/file.txt'))
	assert(w.save_session())
	assert(store.read('last-session').version == 1)
end)

test('closing the final workspace leaves a workspace named main', function()
	assert(#w.list() == 1)
	assert(w.kill())
	assert(#w.list() == 1 and w.current().name == 'main')
end)

test('project settings drafts survive reopening and spell applies to the window', function()
	p.switch(root, function() end)
	p.edit_config()
	api.nvim_buf_set_lines(0, 0, -1, false, { '{"options":{"spell":true}}' })
	p.edit_config()
	assert(api.nvim_get_current_line() == '{"options":{"spell":true}}')
	vim.cmd.write()
	vim.wo.spell = false
	vim.cmd.edit(vim.fn.fnameescape(root .. '/file.txt'))
	assert(vim.wo.spell)
end)

test('project detection follows the buffer and recognizes unversioned manifests', function()
	p.switch(root, function() end)
	vim.cmd.edit(vim.fn.fnameescape(other .. '/other.txt'))
	assert(p.root() == other)
	local repo = temp .. '/monorepo'
	file(repo .. '/.git/HEAD', { 'ref: refs/heads/main' })
	file(repo .. '/child/package.json', { '{}' })
	file(repo .. '/child/a.js')
	assert(p.root(repo .. '/child/a.js') == repo)
	file(repo .. '/child/.projectile', {})
	assert(p.root(repo .. '/child/a.js') == repo .. '/child')
	file(temp .. '/plain/Cargo.toml', {})
	file(temp .. '/plain/src/main.rs')
	assert(p.root(temp .. '/plain/src/main.rs') == temp .. '/plain')
end)

test('returning to a project offers files and explicit skip preserves focus', function()
	p.switch(root, function() end)
	p.switch(other, function() end)
	p.switch(root)
	assert(active.prompt == 'Project files' and not active.closed)
	active:cancel()
	p.switch(other, nil, true)
	assert(active.closed)
end)

test('scratch toggle handles a sole normal window with ui2 floating windows', function()
	p.switch(root, function() end)
	p.scratch(false)
	local buf = api.nvim_get_current_buf()
	assert(#api.nvim_tabpage_list_wins(0) > 1 or #api.nvim_list_wins() > 1)
	p.scratch(true)
	assert(api.nvim_get_current_buf() ~= buf and api.nvim_buf_is_valid(buf))
end)

test('malformed views are rejected before any buffer is altered', function()
	vim.cmd.edit(vim.fn.fnameescape(root .. '/file.txt'))
	local buf, tab = api.nvim_get_current_buf(), api.nvim_get_current_tabpage()
	local data = w.snapshot { tab }
	data.buffers[1].lines = { 'must not apply' }
	data.workspaces[1].layout.view = { lnum = 'broken' }
	assert(not pcall(w.restore, data, false))
	assert(api.nvim_buf_get_lines(buf, 0, -1, false)[1] == 'original')
	assert(api.nvim_get_current_tabpage() == tab)
end)

test('failed restore rolls back staged tabs, text, membership and dirty state', function()
	vim.cmd.edit(vim.fn.fnameescape(root .. '/file.txt'))
	local buf, win = api.nvim_get_current_buf(), api.nvim_get_current_win()
	local before, members = #w.list(), w.buffers()
	local data = w.snapshot { api.nvim_get_current_tabpage() }
	data.buffers[1].lines, data.buffers[1].modified = { 'staged content' }, true
	data.workspaces[2] = vim.deepcopy(data.workspaces[1])
	local new, calls = w.new, 0
	w.new = function(...)
		calls = calls + 1
		local tab = new(...)
		if calls == 2 then
			error 'simulated split failure'
		end
		return tab
	end
	local ok = pcall(w.restore, data, false)
	w.new = new
	assert(not ok and calls == 2)
	assert(#w.list() == before and api.nvim_get_current_win() == win)
	assert(api.nvim_buf_get_lines(buf, 0, -1, false)[1] == 'original' and not vim.bo[buf].modified)
	assert(vim.deep_equal(members, w.buffers()))
end)

test('clone shares unsaved buffers, nested splits and window-local directories', function()
	p.switch(root, function() end)
	vim.cmd.edit(vim.fn.fnameescape(root .. '/file.txt'))
	local buf = api.nvim_get_current_buf()
	api.nvim_buf_set_lines(buf, 0, -1, false, { 'unsaved clone' })
	vim.cmd.vsplit()
	vim.cmd.lcd(vim.fn.fnameescape(other))
	local source = api.nvim_get_current_tabpage()
	assert(w.clone 'cloned')
	assert(api.nvim_get_current_tabpage() ~= source and w.current().name == 'cloned')
	assert(api.nvim_get_current_buf() == buf and vim.bo[buf].modified)
	assert(api.nvim_get_current_line() == 'unsaved clone' and vim.fn.getcwd() == other)
	assert(vim.fn.haslocaldir() == 1)
	assert(#vim.tbl_filter(function(win)
		return api.nvim_win_get_config(win).relative == ''
	end, api.nvim_tabpage_list_wins(0)) == 2)
end)

test('killing a workspace returns to the previously visited workspace', function()
	local a = w.new('A', root)
	local b = w.new('B', root)
	local c = w.new('C', root)
	w.switch(a)
	w.switch(c)
	assert(w.kill())
	assert(api.nvim_get_current_tabpage() == a and api.nvim_tabpage_is_valid(b))
end)

test('command completion does not cancel a picker in the originating tab', function()
	p.switch(root, function() end)
	local id = vim.fn.getqflist({ id = 0 }).id
	p.execute(root, 'sleep 0.05; printf completed', 'async')
	active = picker.open { source = { 'keep open' }, prompt = 'Still choosing' }
	assert(vim.wait(3000, function()
		return vim.fn.getqflist({ id = 0 }).id ~= id
	end))
	assert(not active.closed and api.nvim_get_current_win() == ui2.wins.cmd)
end)

test('build saves buffers and remembers the edited command for the next invocation', function()
	p.switch(root, function() end)
	vim.cmd.edit(vim.fn.fnameescape(root .. '/file.txt'))
	api.nvim_buf_set_lines(0, 0, -1, false, { 'saved before compile' })
	local input, execute = vim.ui.input, p.execute
	local observed
	p.execute = function(_, command)
		observed = command
		assert(vim.fn.readfile(root .. '/file.txt')[1] == 'saved before compile')
	end
	vim.ui.input = function(_, callback)
		callback 'custom-build'
	end
	p.command 'compile'
	vim.ui.input = function(options, callback)
		assert(options.default == 'custom-build')
		callback(nil)
	end
	local ok, err = pcall(p.command, 'compile')
	vim.ui.input, p.execute = input, execute
	assert(ok, err)
	assert(observed == 'custom-build')
end)

test('corrupt registry does not abort startup or get overwritten on exit', function()
	store.write('projects', { known = 42, recent = {} })
	assert(pcall(p.setup))
	p.add(root)
	api.nvim_exec_autocmds('VimLeavePre', { group = 'NativeProjects' })
	assert(store.read('projects').known == 42)
	store.write('projects', { known = {}, recent = {} })
	p.setup()
end)

test('count mappings clone, save, reload and select workspaces', function()
	p.switch(root, function() end)
	vim.cmd.edit(vim.fn.fnameescape(root .. '/file.txt'))
	local original = api.nvim_get_current_tabpage()
	local function keys(text)
		api.nvim_feedkeys(vim.keycode(text), 'xt', false)
	end
	keys '2<Space><Tab>n'
	assert(api.nvim_get_current_tabpage() ~= original and w.current().name:find('copy', 1, true))
	keys '2<Space><Tab>s'
	assert(store.read('saved')[w.current().name])
	local count, name = #w.list(), w.current().name
	keys '2<Space><Tab>l'
	assert(#w.list() == count and w.current().name == name)
	keys '2<Space><Tab>.'
	assert(api.nvim_tabpage_get_number(0) == 2)
end)

api.nvim_del_augroup_by_name 'NativeProjects'
api.nvim_del_augroup_by_name 'NativeWorkspaces'
vim.fn.delete(temp, 'rf')
if #errors > 0 then
	error(table.concat(errors, '\n\n'))
end
print 'PASS all review regressions'
