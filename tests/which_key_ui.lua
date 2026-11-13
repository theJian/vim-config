-- Run with -l, or :luafile in a terminal. A separate embedded Nvim has a real attached UI.
local root = vim.fn.getcwd()
local child = vim.fn.jobstart({ 'nvim', '--embed', '-n', '-u', 'NONE', '-i', 'NONE' }, {
	rpc = true,
	env = { NVIM_LOG_FILE = vim.fn.tempname() },
})
local function call(method, ...)
	return vim.rpcrequest(child, method, ...)
end
local function lua(code, ...)
	return call('nvim_exec_lua', code, { ... })
end
local function input(keys, wait)
	call('nvim_input', keys)
	vim.wait(wait or 30)
end
local function popup()
	return lua [[
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.bo[buf].filetype == 'which-key' then
				return { lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false),
					config = vim.api.nvim_win_get_config(win), current = win == vim.api.nvim_get_current_win() }
			end
		end
		return false
	]]
end
local function has(text)
	local p = popup()
	assert(
		p and table.concat(p.lines, '\n'):find(text, 1, true),
		'Missing popup text: '
			.. text
			.. ' actual: '
			.. vim.inspect(p)
			.. ' mode: '
			.. lua 'return vim.api.nvim_get_mode().mode'
	)
	return p
end
local failures = {}
local function test(name, run)
	input '<Esc>'
	lua [[
		if package.loaded.which_key then require('which_key').disable() end
		vim.cmd('silent! only!')
		vim.cmd.enew({ bang = true })
		vim.g.hit = nil
		vim.g.mapleader = ' '
		vim.o.timeoutlen = 70
		vim.o.ttimeoutlen = 10
		vim.o.timeout = true
		vim.g.maplocalleader = ' '
		vim.keymap.set('n', '<leader>pp', function() vim.g.hit = {vim.v.count, vim.v.register} end, { buffer = true, desc = 'Project action' })
		vim.keymap.set('n', '<leader><Tab>n', '<Cmd>let g:hit="workspace"<CR>', { buffer = true, desc = 'New workspace' })
		vim.keymap.set('n', 'gx', '<Nop>', { buffer = true, desc = 'Custom g action' })
		vim.keymap.set('n', 'zx', '<Nop>', { buffer = true, desc = 'Custom z action' })
		vim.keymap.set('n', '<C-w>x', '<Nop>', { buffer = true, desc = 'Custom window action' })
		function _G.setup_wk(opts)
			require('which_key').setup(vim.tbl_extend('force', {
				groups = { ['<leader>p'] = 'Projects', ['<leader><Tab>'] = 'Workspaces' },
			}, opts or {}))
		end
		setup_wk()
	]]
	vim.wait(30)
	local ok, err = pcall(run)
	if not ok then
		failures[#failures + 1] = name .. ': ' .. tostring(err)
	end
	print((ok and 'PASS: ' or 'FAIL: ') .. name .. (ok and '' or ': ' .. tostring(err)))
end

local ok, err = pcall(function()
	call('nvim_ui_attach', 90, 28, { rgb = true })
	lua('vim.opt.rtp:prepend(...)', root)

	test('prefix delay, nested groups, count and register preservation', function()
		lua [[
			_G.saved_open = vim.api.nvim_open_win
			vim.g.started_at = vim.uv.hrtime()
			vim.api.nvim_open_win = function(...)
				vim.g.opened_after = (vim.uv.hrtime() - vim.g.started_at) / 1e6
				return saved_open(...)
			end
		]]
		input('"a3 ', 120)
		lua 'vim.api.nvim_open_win = saved_open'
		assert(lua 'return vim.g.opened_after' >= 60, 'popup appeared before timeout')
		local p = has 'Projects'
		assert(not p.current and not p.config.focusable)
		input 'p'
		has '<Space>p — Projects'
		has 'Project action'
		input 'p'
		assert(not popup())
		assert(vim.deep_equal(lua 'return vim.g.hit', { 3, 'a' }))
		input(' <Tab>', 120)
		has 'Workspaces'
		input 'n'
		assert(lua 'return vim.g.hit' == 'workspace')
	end)

	test('fast input and ordinary typing perform no popup work or mapping scans', function()
		lua [[
			vim.g.scans, vim.g.opens = 0, 0
			_G.old_getmaps, _G.old_openwin = vim.api.nvim_get_keymap, vim.api.nvim_open_win
			vim.api.nvim_get_keymap = function(...) vim.g.scans = vim.g.scans + 1; return old_getmaps(...) end
			vim.api.nvim_open_win = function(...) vim.g.opens = vim.g.opens + 1; return old_openwin(...) end
		]]
		input(' ppiordinary typing<Esc>', 120)
		local stats = lua 'return {vim.g.scans, vim.g.opens}'
		lua 'vim.api.nvim_get_keymap, vim.api.nvim_open_win = old_getmaps, old_openwin'
		assert(vim.deep_equal(stats, { 0, 0 }), vim.inspect(stats))
	end)

	test('Escape and Ctrl-C close cleanly', function()
		input(' p', 120)
		has 'Project action'
		input '<Esc>'
		assert(not popup() and lua 'return vim.g.hit' == vim.NIL)
		input(' p', 120)
		input '<C-c>'
		assert(not popup())
		input ' pp'
		assert(type(lua 'return vim.g.hit') == 'table')
	end)

	test('native unlisted gg, zz, window commands and invalid continuations', function()
		lua [[vim.api.nvim_buf_set_lines(0,0,-1,false,{'one','two','three'}); vim.api.nvim_win_set_cursor(0,{3,0})]]
		input('g', 120)
		has 'Custom g action'
		input 'g'
		assert(lua 'return vim.fn.line(".")' == 1)
		input('z', 120)
		input 'z'
		assert(not popup())
		lua 'vim.cmd.vsplit(); vim.g.oldwin=vim.api.nvim_get_current_win()'
		input('<C-w>', 120)
		has 'Custom window action'
		input 'w'
		assert(lua 'return vim.api.nvim_get_current_win() ~= vim.g.oldwin')
		input('g', 120)
		input '<F12>'
		assert(not popup())
	end)

	test('buffer-local precedence, descriptions and runtime refresh', function()
		lua [[
			vim.keymap.set('n','<F6>a','<Nop>',{desc='Global description'})
			vim.keymap.set('n','<F6>a','<Cmd>let g:hit="local"<CR>',{buffer=true,desc='Local description'})
			require('which_key').refresh()
		]]
		input('<F6>', 120)
		has 'Local description'
		input 'a'
		assert(lua 'return vim.g.hit' == 'local')
		lua [[vim.keymap.del('n','<F6>a',{buffer=true}); require('which_key').refresh()]]
		input('<F6>', 120)
		has 'Global description'
		input '<Esc>'
		lua [[vim.keymap.del('n','<F6>a'); require('which_key').refresh()]]
	end)

	test('recursive, expression and Plug mappings use native resolution', function()
		lua [[
			vim.keymap.set('n','<Plug>(wk-hit)',function() vim.g.hit='plug' end,{buffer=true})
			vim.keymap.set('n','<F6>a','<Plug>(wk-hit)',{buffer=true,desc='Plug action'})
			vim.keymap.set('n','<F6>b','<F6>a',{buffer=true,remap=true,desc='Recursive action'})
			vim.keymap.set('n','<F6>c',function() return '<F6>a' end,{buffer=true,expr=true,remap=true,desc='Expression action'})
			require('which_key').refresh()
		]]
		for _, key in ipairs { 'a', 'b', 'c' } do
			lua 'vim.g.hit=nil'
			input('<F6>', 120)
			input(key)
			assert(lua 'return vim.g.hit' == 'plug')
		end
	end)

	test('Visual selection, count and register survive slow invocation', function()
		lua [[
			vim.api.nvim_buf_set_lines(0,0,-1,false,{'one','two','three'})
			vim.keymap.set('x','<leader>yy','y',{buffer=true,desc='Yank selection'})
			require('which_key').refresh()
		]]
		input('ggVj"a ', 120)
		has 'mappings'
		input 'yy'
		assert(lua 'return vim.fn.getreg("a")' == 'one\ntwo\n')
	end)

	test('macro recording and playback preserve original keys', function()
		input('qa p', 120)
		input 'pq'
		assert(lua 'return vim.fn.keytrans(vim.fn.getreg("a"))' == '<Space>pp')
		lua 'vim.g.hit=nil'
		input('@a', 160)
		assert(type(lua 'return vim.g.hit') == 'table' and not popup())
	end)

	test('native dot repeat after a slow editing mapping', function()
		lua [[
			vim.api.nvim_buf_set_lines(0,0,-1,false,{'abcdef'})
			vim.keymap.set('n','<F6>x','x',{buffer=true,desc='Delete char'})
			require('which_key').refresh()
		]]
		input('<F6>', 120)
		input 'x.'
		assert(lua 'return vim.api.nvim_get_current_line()' == 'cdef')
	end)

	test('slow input matches native behavior with hints disabled', function()
		local cases = {
			{ before = '3', prefix = '<F6>', after = 'x.', rhs = 'x' },
			{ before = '"="HELLO"<CR>', prefix = '<F6>', after = 'x', rhs = 'p' },
			{
				before = '"=execute("let g:expr_calls += 1") . "HELLO"<CR>',
				prefix = '<F6>',
				after = 'x',
				rhs = 'p',
			},
			{ before = '"a2', prefix = '<F6>', after = 'y', rhs = 'yy' },
			{ before = 'Vj', prefix = '<F6>', after = 'y', rhs = 'y', mode = 'x' },
			{ before = 'V', prefix = '<F6>', after = '<Esc>', rhs = 'y', mode = 'x' },
			{ before = 'V', prefix = '<F6>', after = '<C-c>', rhs = 'y', mode = 'x' },
			{ before = '', prefix = '<F6>', after = 'xHELLO<Esc>', rhs = 'i' },
			{ before = 'G', prefix = 'g', after = 'g' },
			{ before = '', prefix = 'g', after = '<F12>j' },
			{ before = 'i<C-o>', prefix = 'g', after = 'gHELLO<Esc>' },
		}
		for _, case in ipairs(cases) do
			local snapshots = {}
			for _, enabled in ipairs { false, true } do
				input '<Esc>'
				lua(
					[[
					local case,enabled=...
					require('which_key').disable()
					vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true,false))
					vim.api.nvim_buf_set_lines(0,0,-1,false,{'abcdef','ghijkl','mnopqr','stuvwx'})
					vim.api.nvim_win_set_cursor(0,{1,0})
					vim.fn.setreg('a','')
					vim.g.expr_calls=0
					if case.rhs then
						local suffix=(case.rhs=='yy' or case.rhs=='y') and 'y' or 'x'
						vim.keymap.set(case.mode or 'n','<F6>'..suffix,case.rhs,{buffer=true,desc='Comparison'})
					else
						vim.keymap.set('n','gx','<Nop>',{buffer=true,desc='Comparison'})
					end
					vim.o.timeoutlen=enabled and 70 or 500
					if enabled then setup_wk() end
				]],
					case,
					enabled
				)
				input(case.before .. case.prefix, 120)
				input(case.after, 120)
				snapshots[#snapshots + 1] = lua [[
					return {vim.api.nvim_buf_get_lines(0,0,-1,false),vim.api.nvim_win_get_cursor(0),
						vim.fn.getreg('a'),vim.api.nvim_get_mode().mode,vim.g.expr_calls}
				]]
			end
			assert(vim.deep_equal(snapshots[1], snapshots[2]), vim.inspect { case = case, snapshots = snapshots })
		end
	end)

	test('Unicode, special keys and literal angle brackets', function()
		lua [[
			for _, lhs in ipairs({'<M-j>你','<lt>你','你<Right>'}) do
				vim.keymap.set('n',lhs,'<Cmd>let g:hit="unicode"<CR>',{buffer=true,desc='Unicode action'})
			end
			require('which_key').refresh()
		]]
		for _, pair in ipairs { { '<M-j>', '你' }, { '<lt>', '你' }, { '你', '<Right>' } } do
			lua 'vim.g.hit=nil'
			input(pair[1], 120)
			has 'Unicode action'
			input(pair[2])
			assert(lua 'return vim.g.hit' == 'unicode')
		end
	end)

	test('paging, conflicting paging keys, narrow UI and resize', function()
		lua [[
			for i=33,126 do
				local key=string.char(i)
				vim.keymap.set('n','<F6>'..(key=='<' and '<lt>' or key),'<Nop>',{buffer=true,desc='Long Unicode description 中文 '..i})
			end
			setup_wk({max_height=4})
		]]
		input('<F6>', 120)
		has '[1/'
		input '<C-d>'
		has '[2/'
		input '<C-u>'
		has '[1/'
		call('nvim_ui_try_resize', 35, 12)
		vim.wait(50)
		local p = has '[1/'
		assert(p.config.width <= 35 and p.config.height <= 4)
		input '<Esc>'
		lua [[
			vim.keymap.set('n','<F6><C-d>','<Cmd>let g:hit="conflict"<CR>',{buffer=true,desc='Mapped paging key'})
			require('which_key').refresh()
		]]
		input('<F6>', 120)
		input '<C-d>'
		assert(lua 'return vim.g.hit' == 'conflict')
		call('nvim_ui_try_resize', 90, 28)
	end)

	test('exact nested mappings and nowait retain native precedence', function()
		lua [[
			vim.keymap.set('n','<F6>a','<Cmd>let g:hit="short"<CR>',{buffer=true,desc='Exact action'})
			vim.keymap.set('n','<F6>ab','<Cmd>let g:hit="long"<CR>',{buffer=true,desc='Long action'})
			require('which_key').refresh()
		]]
		input('<F6>', 120)
		has 'Exact action'
		input 'ab'
		assert(lua 'return vim.g.hit' == 'long')
		input('<F6>', 120)
		input('a', 120)
		assert(lua 'return vim.g.hit' == 'short' and not popup())
		lua [[
			vim.keymap.set('n','<F6>a','<Cmd>let g:hit="nowait"<CR>',{buffer=true,nowait=true,desc='Nowait action'})
			require('which_key').refresh()
		]]
		input('<F6>', 120)
		input 'a'
		assert(lua 'return vim.g.hit' == 'nowait' and not popup())
	end)

	test('buffer changes and disable wake a pending popup safely', function()
		input(' p', 120)
		has 'Project action'
		lua 'vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))'
		vim.wait(40)
		assert(not popup())
		input 'ihello<Esc>'
		assert(
			lua 'return vim.api.nvim_get_current_line()' == 'hello',
			lua 'return vim.api.nvim_get_current_line()' .. ' / ' .. lua 'return vim.api.nvim_get_mode().mode'
		)
		lua [[
			vim.keymap.set('n','<F6>a','<Nop>',{buffer=true,desc='Action'})
			require('which_key').refresh()
		]]
		input('<F6>', 120)
		has 'Action'
		lua "require('which_key').disable()"
		vim.wait(40)
		assert(not popup())
	end)

	test('ui2 and lazy redraw keep hints visible without taking focus', function()
		lua [[
			require('vim._core.ui2').enable({})
			vim.o.lazyredraw=true
			vim.o.cmdheight=0
			vim.o.laststatus=3
			vim.g.editwin=vim.api.nvim_get_current_win()
		]]
		input(' p', 120)
		local p = has 'Project action'
		assert(not p.current)
		assert(lua 'return vim.api.nvim_get_current_win()==vim.g.editwin')
		input '<Esc>'
		assert(not popup())
		input ' pp'
		assert(type(lua 'return vim.g.hit') == 'table')
	end)
end)
vim.fn.jobstop(child)
if not ok then
	failures[#failures + 1] = tostring(err)
end
if #failures > 0 then
	error(table.concat(failures, '\n'))
end
print 'PASS: all which-key attached-UI scenarios'
