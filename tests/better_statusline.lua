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
	api.nvim_set_hl(0, 'StatusLine', { fg = '#111111', bg = '#eeeeee' })
	api.nvim_set_hl(0, 'TestModeInsert', { fg = '#0055cc', bold = true })
	m.setup {
		mode_colors = {
			normal = { fg = '#222222' },
			insert = 'TestModeInsert',
			visual = { fg = '#aa5500', bg = '#ffddaa' },
			replace = 'MissingModeGroup',
		},
	}
	local function hl(family)
		return api.nvim_get_hl(0, { name = 'BetterStatuslineMode_' .. family, link = false })
	end
	assert(hl('insert').fg == 0x0055cc and hl('insert').bg == 0xeeeeee and hl('insert').bold)
	assert(hl('visual').bg == 0xffddaa)
	assert(hl('select').fg == hl('visual').fg)
	assert(hl('operator').fg == hl('normal').fg)
	assert(hl('replace').fg == 0x111111)
	local get_mode = api.nvim_get_mode
	for _, case in ipairs {
		{ 'n', 'normal' },
		{ 'ic', 'insert' },
		{ 'V', 'visual' },
		{ '\22', 'visual' },
		{ '\19', 'select' },
		{ 'Rvc', 'replace' },
		{ 'r?', 'command' },
		{ 't', 'terminal' },
		{ 'noV', 'operator' },
	} do
		api.nvim_get_mode = function()
			return { mode = case[1] }
		end
		api.nvim_exec_autocmds('ModeChanged', { pattern = 'n:' .. case[1] })
		settle()
		contains(m.statusline(), '%#BetterStatuslineMode_' .. case[2] .. '#')
	end
	api.nvim_get_mode = get_mode
	api.nvim_set_hl(0, 'TestModeInsert', { fg = '#0066dd' })
	api.nvim_set_hl(0, 'StatusLine', { fg = '#111111', bg = '#dddddd' })
	api.nvim_exec_autocmds('ColorScheme', {})
	assert(hl('insert').fg == 0x0066dd and hl('insert').bg == 0xdddddd)
	m.setup()
	assert(hl('insert').fg == 0x111111)
	-- Exercise an actual mode transition as well as the family variants above.
	vim.cmd.normal 'v'
	settle()
	contains(m.statusline(), '%#BetterStatuslineMode_visual#')
	vim.cmd.normal { args = { vim.keycode '<Esc>' }, bang = true }
	settle()
	contains(m.statusline(), '%#BetterStatuslineMode_normal#')
	print 'PASS: mode colors, family fallbacks, transitions, colorscheme reload, reset'
	git('init', '-b', 'status-test')
	git('config', 'diff.interHunkContext', '4')
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
	-- Staging changes the index without a buffer write or entry event.
	git('add', 'sample.lua')
	api.nvim_exec_autocmds('User', {
		pattern = 'GitSignsUpdate',
		data = { buffer = api.nvim_get_current_buf() },
	})
	assert(
		vim.wait(3000, function()
			return not status():find('+1', 1, true) and not status():find('~1', 1, true)
		end),
		'staged changes remained in the saved diff cache'
	)
	git('reset', 'HEAD', '--', 'sample.lua')
	-- Repository-wide updates can omit the buffer payload.
	api.nvim_exec_autocmds('User', { pattern = 'GitSignsUpdate' })
	assert(
		vim.wait(3000, function()
			return status():find('+1', 1, true) and status():find('~1', 1, true)
		end),
		'unstaged changes did not return after a repository update'
	)
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
