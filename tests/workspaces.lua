-- nvim --headless -u NONE -i NONE -l tests/workspaces.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
require 'keymaps'
vim.g.mapleader = ' '
vim.o.hidden = true
vim.o.swapfile = false
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
ui2.cmd = require 'vim._core.ui2.cmdline'
ui2.msg = require 'vim._core.ui2.messages'
ui2.check_targets()
local picker = require 'better_select'
local active
local open = picker.open
picker.open = function(opts)
	active = open(opts)
	return active
end
local w, p = require 'workspaces', require 'projects'
w.setup()
p.setup()
local failures = {}
local function flush()
	vim.wait(30, function()
		return false
	end, 1)
end
local function test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if active then
		active:close()
	end
	flush()
	if not ok then
		failures[#failures + 1] = name .. ': ' .. err
	end
	print((ok and 'PASS ' or 'FAIL ') .. name)
end
local function press(key)
	local mapping = vim.fn.maparg('<leader>' .. key, 'n', false, true)
	mapping = vim.fn.maparg(mapping.rhs, 'n', false, true)
	assert(type(mapping.callback) == 'function', 'Missing mapping ' .. key)
	mapping.callback()
end
local function select(query)
	active:set_query(query)
	assert(active:get_current(), 'No picker match: ' .. query)
	active:accept()
	flush()
end
local function input(value, fn)
	local previous = vim.ui.input
	vim.ui.input = function(_, callback)
		callback(value)
	end
	local ok, err = pcall(fn)
	vim.ui.input = previous
	assert(ok, err)
end
local function file(path, lines)
	vim.fn.mkdir(vim.fs.dirname(path), 'p')
	vim.fn.writefile(lines or { path }, path)
end
local alpha, beta = temp .. '/alpha space', temp .. '/beta'
file(alpha .. '/.projectile', {})
file(alpha .. '/src/main.lua', { 'one', 'two', 'three' })
file(alpha .. '/src/main_test.lua')
file(alpha .. '/src/other.lua')
file(beta .. '/.projectile', {})
file(beta .. '/file.lua')

test('every documented project and workspace binding exists', function()
	for _, key in ipairs {
		'.',
		'>',
		'!',
		'&',
		'a',
		'b',
		'c',
		'C',
		'd',
		'D',
		'e',
		'f',
		'F',
		'g',
		'i',
		'k',
		'o',
		'p',
		'r',
		'R',
		's',
		'T',
		'x',
		'X',
	} do
		assert(vim.fn.maparg('<leader>p' .. key, 'n') ~= '', key)
	end
	for _, key in ipairs {
		'<Tab>',
		'.',
		'`',
		'n',
		'N',
		'l',
		's',
		'x',
		'd',
		'D',
		'r',
		'R',
		']',
		'[',
		'0',
		'1',
		'2',
		'3',
		'4',
		'5',
		'6',
		'7',
		'8',
		'9',
	} do
		assert(vim.fn.maparg('<leader><Tab>' .. key, 'n') ~= '', key)
	end
end)

test('add, remove and discover project directories with persistent registry', function()
	input(alpha, function()
		press 'pa'
	end)
	assert(vim.tbl_contains(p.list(), alpha))
	assert(store.read('projects').known[alpha])
	local done
	p.discover(temp, function(found)
		done = found
	end)
	assert(vim.wait(3000, function()
		return done ~= nil
	end))
	assert(vim.tbl_contains(done, beta))
	press 'pd'
	select 'beta'
	assert(not vim.tbl_contains(p.list(), beta))
	p.add(beta)
end)

test('project picker creates one workspace per canonical root', function()
	press 'pp'
	select 'alpha space'
	assert(p.root() == alpha)
	assert(vim.wait(3000, function()
		return #active.items > 0
	end))
	select 'main.lua'
	assert(api.nvim_buf_get_name(0) == alpha .. '/src/main.lua')
	local tab = api.nvim_get_current_tabpage()
	assert(w.current().name == 'alpha space')
	p.switch(beta, function() end)
	p.switch(alpha, function() end)
	assert(api.nvim_get_current_tabpage() == tab)
	assert(vim.fn.getcwd() == alpha)
end)

test('workspace membership, views and tab navigation stay independent', function()
	local original = api.nvim_get_current_buf()
	api.nvim_win_set_cursor(0, { 2, 1 })
	vim.cmd.vsplit()
	vim.cmd.edit(vim.fn.fnameescape(alpha .. '/src/other.lua'))
	local first = api.nvim_get_current_tabpage()
	p.switch(beta, function() end)
	local second = api.nvim_get_current_tabpage()
	assert(not vim.tbl_contains(w.buffers(), original))
	press '<Tab>`'
	assert(api.nvim_get_current_tabpage() == first)
	assert(#vim.tbl_filter(function(win)
		return api.nvim_win_get_config(win).relative == ''
	end, api.nvim_tabpage_list_wins(first)) == 2)
	press '<Tab>`'
	assert(api.nvim_get_current_tabpage() == second)
	press '<Tab>1'
	assert(api.nvim_tabpage_get_number(0) == 1)
	press '<Tab>0'
	assert(api.nvim_get_current_tabpage() == second)
	press '<Tab>]'
	assert(api.nvim_tabpage_get_number(0) == 1)
	press '<Tab>['
	assert(api.nvim_get_current_tabpage() == second)
end)

test('workspace picker, named creation, rename and display', function()
	input('investigation', function()
		press '<Tab>N'
	end)
	assert(w.current().name == 'investigation')
	input('debug', function()
		press '<Tab>r'
	end)
	assert(vim.t.tabname == 'debug')
	press '<Tab><Tab>'
	press '<Tab>.'
	select '/^alpha space/'
	assert(w.current().name == 'alpha space')
end)

test('file picker fallback, cache invalidation, recent and sibling files', function()
	press 'pf'
	assert(vim.wait(3000, function()
		return #active.items > 0
	end))
	select 'main.lua'
	press 'pr'
	assert(active:get_current().v == alpha .. '/src/main.lua')
	active:cancel()
	flush()
	press 'po'
	assert(vim.wait(3000, function()
		return #active.items > 0
	end))
	assert(not vim.tbl_contains(
		vim.tbl_map(function(entry)
			return entry.v
		end, active.items),
		alpha .. '/src/main.lua'
	))
	select 'main_test.lua'
	file(alpha .. '/new.lua')
	press 'pi'
	press 'pf'
	assert(vim.wait(3000, function()
		return #active.items > 0
	end))
	select 'new.lua'
	assert(api.nvim_buf_get_name(0) == alpha .. '/new.lua')
end)

test('Git indexing respects ignores, untracked paths, spaces and deletions', function()
	local root = temp .. '/git'
	file(root .. '/.gitignore', { 'ignored' })
	file(root .. '/tracked space.lua')
	file(root .. '/ignored')
	assert(vim.system({ 'git', 'init', root }):wait().code == 0)
	assert(vim.system({ 'git', '-C', root, 'add', '.' }):wait().code == 0)
	file(root .. '/untracked.lua')
	file(root .. '/deleted.lua')
	assert(vim.system({ 'git', '-C', root, 'add', 'deleted.lua' }):wait().code == 0)
	vim.fn.delete(root .. '/deleted.lua')
	local files
	p.files(root, function(result)
		files = result
	end)
	assert(vim.wait(3000, function()
		return files ~= nil
	end))
	assert(vim.tbl_contains(files, root .. '/tracked space.lua'))
	assert(vim.tbl_contains(files, root .. '/untracked.lua'))
	assert(not vim.tbl_contains(files, root .. '/ignored'))
	assert(not vim.tbl_contains(files, root .. '/deleted.lua'))
end)

test('project scratch toggles and remains separate from other projects', function()
	press 'px'
	local scratch = api.nvim_get_current_buf()
	api.nvim_buf_set_lines(scratch, 0, -1, false, { 'project notes' })
	press 'px'
	assert(api.nvim_get_current_buf() ~= scratch)
	press 'pX'
	assert(api.nvim_get_current_buf() == scratch)
	p.switch(beta, function() end)
	press 'pX'
	assert(api.nvim_get_current_buf() ~= scratch)
	p.switch(alpha, function() end)
	press 'pX'
	assert(api.nvim_get_current_line() == 'project notes')
end)

test('saved workspace restores nested splits, views, scratch text and cwd', function()
	vim.cmd.edit(vim.fn.fnameescape(alpha .. '/src/main.lua'))
	api.nvim_win_set_cursor(0, { 3, 1 })
	vim.cmd.split()
	press 'pX'
	local before = w.snapshot { api.nvim_get_current_tabpage() }
	input('saved alpha', function()
		press '<Tab>s'
	end)
	assert(store.read('saved')['saved alpha'])
	-- Saved scratch text must survive a restart, not overwrite a live dirty buffer.
	for _, buf in ipairs(w.buffers()) do
		vim.bo[buf].modified = false
	end
	press '<Tab>l'
	select 'saved alpha'
	local after = w.snapshot { api.nvim_get_current_tabpage() }
	assert(vim.fn.getcwd() == alpha)
	assert(#api.nvim_tabpage_list_wins(0) == 3)
	assert(api.nvim_get_current_line() == 'project notes')
	assert(after.workspaces[1].layout.kind == before.workspaces[1].layout.kind)
	local restored_scratch = api.nvim_get_current_buf()
	press 'pX'
	assert(api.nvim_get_current_buf() == restored_scratch)
	press '<Tab>D'
	select 'saved alpha'
	assert(store.read('saved')['saved alpha'] == nil)
end)

test('dirty buffers prevent destructive workspace and project operations', function()
	w.new('dirty', beta)
	local buf = api.nvim_get_current_buf()
	api.nvim_buf_set_lines(buf, 0, -1, false, { 'do not lose' })
	local count = #w.list()
	assert(w.kill() == false and #w.list() == count)
	assert(w.clear() == false and #w.list() == count)
	assert(w.restore(w.snapshot(), true) == false)
	assert(api.nvim_get_current_line() == 'do not lose')
	vim.bo[buf].modified = false
	assert(w.kill())
end)

test('unnamed modified buffers restore as writable ordinary buffers', function()
	w.new('draft', alpha)
	api.nvim_buf_set_lines(0, 0, -1, false, { 'unfinished draft' })
	local snapshot = w.snapshot { api.nvim_get_current_tabpage() }
	vim.bo.modified = false
	assert(w.restore(snapshot, false))
	assert(vim.bo.buftype == '' and vim.bo.modified)
	vim.cmd.write(vim.fn.fnameescape(alpha .. '/draft.txt'))
	assert(vim.fn.readfile(alpha .. '/draft.txt')[1] == 'unfinished draft')
end)

test('corrupt snapshots and conflicting text are rejected before replacing tabs', function()
	local count = #w.list()
	assert(not pcall(w.restore, {
		version = 1,
		buffers = {},
		workspaces = { { name = 'bad', root = '/', buffers = {}, layout = { kind = 'leaf', buffer = 99 } } },
	}, true))
	assert(#w.list() == count)
	file(store.directory() .. '/broken.json', { '{broken' })
	assert(not pcall(store.read, 'broken'))
end)

test('save project buffers and refuse dirty project kills', function()
	p.switch(beta, function() end)
	vim.cmd.edit(vim.fn.fnameescape(beta .. '/file.lua'))
	api.nvim_buf_set_lines(0, 0, -1, false, { 'updated' })
	assert(p.kill() == false)
	press 'ps'
	assert(vim.fn.readfile(beta .. '/file.lua')[1] == 'updated')
	assert(not vim.bo.modified)
end)

test('project configuration creates editable JSON and applies local settings', function()
	press 'pe'
	assert(api.nvim_buf_get_name(0) == beta .. '/.nvim-project.json')
	api.nvim_buf_set_lines(0, 0, -1, false, { '{"compile":"printf compiled", "options":{"shiftwidth":7}}' })
	vim.cmd.write()
	vim.cmd.edit(vim.fn.fnameescape(beta .. '/file.lua'))
	assert(vim.bo.shiftwidth == 7)
	assert(p.config(beta).compile == 'printf compiled')
end)

test('shell, asynchronous command and repeat execute in project root', function()
	input('pwd', function()
		press 'p!'
	end)
	assert(vim.fn.getqflist({ title = 0 }).title:find('pwd', 1, true))
	assert(vim.fn.getqflist()[1].text == beta)
	vim.cmd.cclose()
	input('printf asynchronous', function()
		press 'p&'
	end)
	assert(vim.wait(3000, function()
		return (vim.fn.getqflist()[1] or {}).text == 'asynchronous'
	end))
	vim.cmd.cclose()
	local id = vim.fn.getqflist({ id = 0 }).id
	press 'pC'
	assert(vim.wait(3000, function()
		return vim.fn.getqflist({ id = 0 }).id ~= id
	end))
	assert(vim.fn.getqflist()[1].text == 'asynchronous')
	pcall(vim.cmd.cclose)
end)

test('configure, compile and test commands execute and run uses a terminal', function()
	for _, spec in ipairs { { 'pg', 'configured' }, { 'pc', 'compiled' }, { 'pT', 'tested' } } do
		local id = vim.fn.getqflist({ id = 0 }).id
		input('printf ' .. spec[2], function()
			press(spec[1])
		end)
		assert(vim.wait(3000, function()
			return vim.fn.getqflist({ id = 0 }).id ~= id
		end))
		assert(vim.fn.getqflist()[1].text == spec[2])
		vim.cmd.cclose()
	end
	input('printf running', function()
		press 'pR'
	end)
	assert(vim.bo.buftype == 'terminal' and vim.b.project_root == beta)
	local buf = api.nvim_get_current_buf()
	assert(vim.wait(3000, function()
		return table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), '\n'):find('running', 1, true) ~= nil
	end))
	vim.cmd.stopinsert()
	vim.cmd.close()
end)

test('compiler paths resolve in project root without changing cwd scope or stealing focus', function()
	p.switch(beta, function() end)
	local efm = vim.o.errorformat
	vim.o.errorformat = '%f:%l:%c:%m'
	local id = vim.fn.getqflist({ id = 0 }).id
	p.execute(beta, "printf 'file.lua:1:1:diagnostic'", 'async')
	p.switch(alpha, function() end)
	local tab, win, cwd, scope =
		api.nvim_get_current_tabpage(), api.nvim_get_current_win(), vim.fn.getcwd(), vim.fn.haslocaldir()
	assert(vim.wait(3000, function()
		return vim.fn.getqflist({ id = 0 }).id ~= id
	end))
	local item = vim.fn.getqflist()[1]
	assert(api.nvim_buf_get_name(item.bufnr) == beta .. '/file.lua')
	assert(api.nvim_get_current_tabpage() == tab and api.nvim_get_current_win() == win)
	assert(
		vim.fn.getcwd() == cwd and vim.fn.haslocaldir() == scope,
		vim.inspect { before = { cwd, scope }, after = { vim.fn.getcwd(), vim.fn.haslocaldir() } }
	)
	vim.o.errorformat = efm
end)

test('project buffer picker, other-project file picker and successful project kill', function()
	press 'pb'
	select 'main.lua'
	assert(api.nvim_buf_get_name(0) == alpha .. '/src/main.lua')
	press 'pF'
	select 'beta'
	assert(vim.wait(3000, function()
		return #active.items > 0
	end))
	select 'file.lua'
	assert(p.root() == beta and api.nvim_buf_get_name(0) == beta .. '/file.lua')
	local buf = api.nvim_get_current_buf()
	press 'pk'
	assert(not api.nvim_buf_is_valid(buf))
end)

test('closing a workspace keeps shared buffers and removes exclusive buffers', function()
	w.new('shared owner', alpha)
	vim.cmd.edit(vim.fn.fnameescape(alpha .. '/src/main.lua'))
	local shared = api.nvim_get_current_buf()
	w.new('shared visitor', alpha)
	api.nvim_set_current_buf(shared)
	vim.cmd.enew()
	local exclusive = api.nvim_get_current_buf()
	press '<Tab>d'
	assert(api.nvim_buf_is_valid(shared) and not api.nvim_buf_is_valid(exclusive))
end)

test('directory browsing uses better_select for both current and other projects', function()
	p.switch(alpha, function() end)
	press 'p.'
	select 'src/'
	assert(active.prompt:find('/src', 1, true))
	select 'main_test.lua'
	assert(api.nvim_buf_get_name(0) == alpha .. '/src/main_test.lua')
	press 'p>'
	select 'beta'
	assert(active.prompt:find('/beta', 1, true))
	select 'file.lua'
	assert(api.nvim_buf_get_name(0) == beta .. '/file.lua')
end)

test('session roundtrip restores all workspaces and active tab', function()
	for _, buf in ipairs(api.nvim_list_bufs()) do
		vim.bo[buf].modified = false
	end
	local snapshot = w.snapshot()
	store.write('last-session', snapshot)
	local names = vim.tbl_map(function(item)
		return item.name
	end, w.list())
	assert(w.clear())
	press '<Tab>R'
	assert(vim.deep_equal(
		vim.tbl_map(function(item)
			return item.name
		end, w.list()),
		names
	))
	assert(api.nvim_tabpage_get_number(0) == snapshot.active)
end)

test('auto-save leaves recovered text untouched until the next edit', function()
	require 'autocmds'
	local path = alpha .. '/recover.txt'
	file(path, { 'disk version' })
	w.new('recovery', alpha)
	vim.cmd.edit(vim.fn.fnameescape(path))
	api.nvim_buf_set_lines(0, 0, -1, false, { 'recovered version' })
	local snapshot = w.snapshot { api.nvim_get_current_tabpage() }
	vim.bo.modified = false
	assert(w.restore(snapshot, false))
	api.nvim_exec_autocmds('TextChanged', { buffer = 0 })
	assert(vim.fn.readfile(path)[1] == 'disk version' and vim.bo.modified)
	api.nvim_buf_set_lines(0, 0, -1, false, { 'intentional edit' })
	api.nvim_exec_autocmds('TextChanged', { buffer = 0 })
	assert(vim.fn.readfile(path)[1] == 'intentional edit' and not vim.bo.modified)
end)

api.nvim_del_augroup_by_name 'NativeWorkspaces'
api.nvim_del_augroup_by_name 'NativeProjects'
vim.fn.delete(temp, 'rf')
if #failures > 0 then
	error(table.concat(failures, '\n\n'))
end
print 'PASS all workspace/project integration tests'
