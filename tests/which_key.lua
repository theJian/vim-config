vim.opt.rtp:prepend(vim.fn.getcwd())
local wk = require 'which_key'
local failures = {}
local function test(name, run)
	wk.disable()
	vim.cmd.enew()
	local ok, err = pcall(run)
	wk.disable()
	if not ok then
		failures[#failures + 1] = name .. ': ' .. tostring(err)
	end
	print((ok and 'PASS: ' or 'FAIL: ') .. name)
end
local function map(lhs, opts)
	vim.keymap.set('n', lhs, '<Nop>', vim.tbl_extend('force', { buffer = true, desc = lhs }, opts or {}))
end
local function mapping(lhs, m)
	return vim.fn.maparg(lhs, m or 'n', false, true)
end

test('discovers mapped roots and preserves exact mappings', function()
	map '<F6>ab'
	map '<F7>'
	map '<F7>a'
	map '<Plug>(which-key-test)'
	wk.setup()
	assert(mapping('<F6>').desc == 'Which-key prefix')
	assert(mapping('<F7>').desc == '<F7>')
	assert(vim.tbl_isempty(mapping '<Plug>'))
end)

test('refresh discovers added and deleted mappings', function()
	wk.setup()
	map '<F8>a'
	wk.refresh()
	assert(mapping('<F8>').desc == 'Which-key prefix')
	vim.keymap.del('n', '<F8>a', { buffer = true })
	wk.refresh()
	assert(vim.tbl_isempty(mapping '<F8>'))
end)

test('setup and disable preserve externally replaced triggers', function()
	map '<F6>a'
	wk.setup()
	wk.setup()
	map('<F6>', { desc = 'User replacement' })
	wk.disable()
	assert(mapping('<F6>').desc == 'User replacement')
	assert(#vim.api.nvim_get_autocmds { event = 'SafeState', pattern = '*' } == 0)
end)

test('global exact mappings are not shadowed', function()
	vim.keymap.set('n', '<F9>', '<Nop>', { desc = 'Global exact' })
	map '<F9>x'
	wk.setup()
	assert(mapping('<F9>').desc == 'Global exact' and mapping('<F9>').buffer == 0)
	vim.keymap.del('n', '<F9>')
end)

test('special keys, literal angle brackets and Unicode roots', function()
	map '<M-j>x'
	map '你a'
	map '<lt>x'
	wk.setup()
	assert(mapping('<M-j>').desc == 'Which-key prefix')
	assert(mapping('你').desc == 'Which-key prefix')
	assert(mapping('<lt>').desc == 'Which-key prefix')
end)

test('only requested modes receive triggers', function()
	vim.keymap.set({ 'n', 'x', 'i', 'o', 'c', 't' }, '<F10>a', '<Nop>', { buffer = true })
	wk.setup { modes = { 'x' } }
	assert(mapping('<F10>', 'x').desc == 'Which-key prefix')
	for _, m in ipairs { 'n', 'i', 'o', 'c', 't' } do
		assert(vim.tbl_isempty(mapping('<F10>', m)))
	end
end)

test('native count, register, macro and operator entry points remain unmapped', function()
	for _, lhs in ipairs { '1a', '"x', 'da', 'ca', 'ya', 'ra', 'qa', '@a' } do
		map(lhs)
	end
	wk.setup()
	for _, lhs in ipairs { '1', '"', 'd', 'c', 'y', 'r', 'q', '@' } do
		assert(vim.tbl_isempty(mapping(lhs)))
	end
end)

test('wiped buffers release their triggers and setup remains usable', function()
	map '<F6>a'
	wk.setup()
	local buf = vim.api.nvim_get_current_buf()
	vim.cmd.enew()
	vim.api.nvim_buf_delete(buf, { force = true })
	wk.refresh()
	wk.disable()
	wk.setup()
end)

if #failures > 0 then
	error(table.concat(failures, '\n'))
end
