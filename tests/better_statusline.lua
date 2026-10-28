vim.opt.rtp:prepend(vim.fn.getcwd())
local api = vim.api
local m = require 'better_statusline'
local function settle()
	vim.wait(100, function()
		return false
	end, 10)
end
local function contains(text, needle)
	assert(text:find(needle, 1, true), needle .. ' missing from ' .. text)
end
local function bar(win)
	return api.nvim_eval_statusline(vim.wo[win].winbar, { winid = win, use_winbar = true, maxwidth = 240 }).str
end
local function status()
	return api.nvim_eval_statusline(vim.o.statusline, { maxwidth = 240 }).str
end
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, 'p')
local function git(...)
	local args = { 'git', '-C', temp }
	vim.list_extend(args, { ... })
	local r = vim.system(args, { text = true }):wait()
	assert(r.code == 0, r.stderr)
	return vim.trim(r.stdout)
end
local ok, err = xpcall(function()
	git('init', '-b', 'status-test')
	vim.fn.writefile({ 'one', 'two', 'three' }, temp .. '/sample.lua')
	git('add', '.')
	git('-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-m', 'initial')
	vim.fn.writefile({ 'ONE', 'two', 'three', 'four' }, temp .. '/sample.lua')
	vim.cmd.edit(temp .. '/sample.lua')
	vim.bo.filetype = 'lua'
	m.setup()
	assert(vim.wait(3000, function()
		return status():find('+1', 1, true) and status():find('status-test', 1, true)
	end))
	contains(status(), '~1')
	contains(status(), 'NORMAL')
	contains(status(), os.date '%H:%M')
	api.nvim_win_set_cursor(0, { 2, 1 })
	contains(status(), '2:2')
	local first = api.nvim_get_current_win()
	local buf = api.nvim_get_current_buf()
	vim.bo.modified, vim.bo.readonly = true, true
	local ns = api.nvim_create_namespace 'statusline-test'
	vim.diagnostic.set(ns, buf, {
		{ lnum = 0, col = 0, message = 'error', severity = 1 },
		{ lnum = 1, col = 0, message = 'warning', severity = 2 },
		{ lnum = 1, col = 0, message = 'info', severity = 3 },
		{ lnum = 1, col = 0, message = 'hint', severity = 4 },
	})
	settle()
	contains(bar(first), 'sample.lua ● 󰌾')
	for _, symbol in ipairs { '● 1', '○ 1', '⊙ 1', 'lua' } do
		contains(bar(first), symbol)
	end
	vim.cmd.vnew()
	api.nvim_buf_set_name(0, temp .. '/100%#Error#你好.lua')
	settle()
	contains(bar(api.nvim_get_current_win()), '100%#Error#你好.lua')
	contains(bar(first), 'sample.lua ● 󰌾')
	vim.cmd.tabnew()
	vim.t.tabname = 'custom%tab'
	m.refresh()
	settle()
	contains(m.tabline(), '1[+]')
	contains(m.tabline(), 'custom%%tab')
	assert(vim.o.showtabline == 1)
	vim.fn.jobstart({ 'sh', '-c', 'printf terminal' }, { term = true })
	m.refresh()
	settle()
	assert(vim.wo.winbar == '')
	vim.cmd.enew()
	local clients = vim.lsp.get_clients
	vim.lsp.get_clients = function()
		return { { id = 999, name = 'test-lsp' } }
	end
	local function progress(kind, token)
		api.nvim_exec_autocmds(
			'LspProgress',
			{ data = { client_id = 999, params = { token = token, value = { kind = kind } } } }
		)
		settle()
	end
	progress('begin', 'a')
	progress('begin', 'b')
	progress('end', 'a')
	contains(bar(api.nvim_get_current_win()), 'test-lsp ')
	assert(not bar(api.nvim_get_current_win()):find('test-lsp ✓', 1, true))
	progress('end', 'b')
	contains(bar(api.nvim_get_current_win()), 'test-lsp ✓')
	vim.lsp.get_clients = clients
	-- Cached renderers must not query services, spawn commands, or inspect files.
	local saved = { vim.system, vim.diagnostic.count, vim.lsp.get_clients, api.nvim_list_tabpages }
	local function forbidden()
		error 'expensive work during rendering'
	end
	vim.system, vim.diagnostic.count, vim.lsp.get_clients, api.nvim_list_tabpages =
		forbidden, forbidden, forbidden, forbidden
	local start = vim.uv.hrtime()
	for _ = 1, 10000 do
		m.statusline()
		m.winbar()
		m.tabline()
	end
	local elapsed = (vim.uv.hrtime() - start) / 1e6
	vim.system, vim.diagnostic.count, vim.lsp.get_clients, api.nvim_list_tabpages = unpack(saved)
	print(('PASS: 10,000 cached render triplets in %.2f ms'):format(elapsed))
	m.setup()
	settle()
	assert(#api.nvim_get_autocmds { group = 'BetterStatusline', event = 'ModeChanged' } == 1)
	vim.cmd('buffer! ' .. buf)
	git('checkout', '--detach')
	vim.b.gitsigns_head = nil
	m.setup()
	local hash = git('rev-parse', '--short=6', 'HEAD')
	assert(vim.wait(3000, function()
		return status():find(hash, 1, true) ~= nil
	end))
end, debug.traceback)
vim.fn.delete(temp, 'rf')
if not ok then
	api.nvim_err_writeln(err)
	vim.cmd.cquit()
end
print 'PASS: better_statusline information, splits, escaping, LSP, Git, lifecycle'
vim.cmd 'qa!'
