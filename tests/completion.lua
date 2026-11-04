package.path = table.concat({
	vim.fn.getcwd() .. '/lua/?.lua',
	vim.fn.getcwd() .. '/lua/?/init.lua',
	package.path,
}, ';')

local failures = {}

local function test(name, callback)
	local ok, err = pcall(callback)
	if ok then
		vim.api.nvim_out_write('PASS: ' .. name .. '\n')
	else
		table.insert(failures, name .. ': ' .. err)
		vim.api.nvim_err_writeln('FAIL: ' .. name .. ': ' .. err)
	end
end

local function load_completion()
	pcall(vim.keymap.del, 'i', '<CR>')
	pcall(vim.keymap.del, 'i', '<Right>')
	local completion = dofile(vim.fn.getcwd() .. '/after/plugin/completion.lua')
	vim.api.nvim_exec_autocmds('VimEnter', { group = 'NativeCompletion' })
	return completion
end

local function mapping(lhs, expr)
	local result = vim.fn.maparg(lhs, 'i', false, true)
	assert(type(result.callback) == 'function', lhs .. ' must be a Lua callback mapping')
	assert(result.expr == (expr == false and 0 or 1), lhs .. ' has the wrong expression setting')
	return result.callback
end

local function override(target, replacements, callback)
	local originals = {}
	for name, replacement in pairs(replacements) do
		originals[name] = target[name]
		target[name] = replacement
	end

	local ok, result = pcall(callback)
	for name in pairs(replacements) do
		target[name] = originals[name]
	end
	assert(ok, result)
	return result
end

test('enables fuzzy completion without disabling fuzzy sorting', function()
	load_completion()
	assert(vim.deep_equal(vim.opt.completeopt:get(), { 'fuzzy', 'menuone', 'noselect', 'popup' }))
	assert(vim.o.autocomplete)
	assert(vim.opt.complete:get()[1] == 'o')
end)

test('enables autocomplete only in normal buffers on entry', function()
	local global_autocomplete = vim.opt_global.autocomplete:get()
	load_completion()
	assert(vim.opt_global.autocomplete:get() == global_autocomplete)
	local original = vim.api.nvim_get_current_buf()
	for _, buftype in ipairs { '', 'nofile', 'nowrite', 'acwrite', 'quickfix', 'help', 'prompt' } do
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.bo[bufnr].buftype = buftype
		vim.api.nvim_set_current_buf(bufnr)
		assert(vim.bo.autocomplete == (buftype == ''), 'wrong autocomplete setting for ' .. buftype)
		vim.api.nvim_set_current_buf(original)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end
	local terminal = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(terminal)
	assert(vim.fn.jobstart({ '/bin/sh', '-c', 'exit 0' }, { term = true }) > 0)
	assert(vim.bo.buftype == 'terminal' and not vim.bo.autocomplete)
	vim.api.nvim_set_current_buf(original)
	vim.api.nvim_buf_delete(terminal, { force = true })
end)

test('uses popup navigation before snippet navigation and fallback', function()
	load_completion()
	local tab = mapping '<Tab>'
	local shift_tab = mapping '<S-Tab>'

	override(vim.fn, {
		pumvisible = function()
			return 1
		end,
	}, function()
		assert(tab() == '<C-n>')
		assert(shift_tab() == '<C-p>')
	end)

	override(vim.fn, {
		pumvisible = function()
			return 0
		end,
	}, function()
		override(vim.snippet, {
			active = function(opts)
				return opts.direction == 1
			end,
		}, function()
			assert(tab() == '<Cmd>lua vim.snippet.jump(1)<CR>')
		end)

		override(vim.snippet, {
			active = function(opts)
				return opts.direction == -1
			end,
		}, function()
			assert(shift_tab() == '<Cmd>lua vim.snippet.jump(-1)<CR>')
		end)

		override(vim.snippet, {
			active = function()
				return false
			end,
		}, function()
			assert(tab() == '<Tab>')
			assert(shift_tab() == '<S-Tab>')
		end)
	end)
end)

test('preserves existing enter behavior when no completion item is selected', function()
	pcall(vim.keymap.del, 'i', '<CR>')
	local fallback_calls = 0
	vim.keymap.set('i', '<CR>', function()
		fallback_calls = fallback_calls + 1
		return '<C-]><CR>'
	end, { expr = true, desc = 'Test Enter fallback' })

	dofile(vim.fn.getcwd() .. '/after/plugin/completion.lua')
	vim.api.nvim_exec_autocmds('VimEnter', { group = 'NativeCompletion' })
	local enter = mapping '<CR>'

	override(vim.fn, {
		pumvisible = function()
			return 0
		end,
	}, function()
		assert(enter() == '<C-]><CR>')
	end)

	override(vim.fn, {
		pumvisible = function()
			return 1
		end,
		complete_info = function()
			return { selected = -1 }
		end,
	}, function()
		assert(enter() == '<C-]><CR>')
	end)
	assert(fallback_calls == 2)
end)

for _, order in ipairs { { 'completion', 'pairs' }, { 'pairs', 'completion' } } do
	test('composes at VimEnter in ' .. table.concat(order, '-then-') .. ' order', function()
		pcall(vim.keymap.del, 'i', '<CR>')
		pcall(vim.keymap.del, 'i', '<Right>')
		local fallback_calls = 0
		local blink = {
			setup = function()
				vim.keymap.set('i', '<CR>', function()
					fallback_calls = fallback_calls + 1
					return '<C-]><CR>'
				end, { expr = true, silent = true })
			end,
		}
		local function source(name)
			dofile(vim.fn.getcwd() .. '/after/plugin/' .. name .. '.lua')
		end
		override(vim.pack, {
			use = function(spec)
				assert(spec[1] == 'blink.pairs')
				return blink
			end,
		}, function()
			source(order[1])
			source(order[2])
			local blink_enter = mapping '<CR>'
			assert(vim.fn.maparg('<Right>', 'i') == '', 'Right must wait for VimEnter')
			assert(#vim.api.nvim_get_autocmds { event = 'VimEnter', group = 'NativeCompletion' } == 1)
			vim.api.nvim_exec_autocmds('VimEnter', { group = 'NativeCompletion' })
			local enter = mapping '<CR>'
			local right = mapping '<Right>'
			assert(enter ~= blink_enter, 'VimEnter must wrap the completed Blink mapping')
			assert(#vim.api.nvim_get_autocmds { event = 'VimEnter', group = 'NativeCompletion' } == 0)
			vim.api.nvim_exec_autocmds('VimEnter', { group = 'NativeCompletion' })
			assert(mapping '<CR>' == enter and mapping '<Right>' == right, 'the hook must run only once')
			for _, state in ipairs {
				{ popup = 0, selected = -1, expected = '<C-]><CR>' },
				{ popup = 1, selected = -1, expected = '<C-]><CR>' },
				{ popup = 1, selected = 0, expected = '<C-y>' },
			} do
				override(vim.fn, {
					pumvisible = function()
						return state.popup
					end,
					complete_info = function()
						assert(state.popup == 1, 'no popup must bypass complete_info')
						return { selected = state.selected }
					end,
				}, function()
					assert(enter() == state.expected)
				end)
			end
			assert(fallback_calls == 2, 'each fallback must run once; acceptance must bypass it')
		end)
	end)
end

test('captures an Enter mapping installed after completion setup', function()
	pcall(vim.keymap.del, 'i', '<CR>')
	dofile(vim.fn.getcwd() .. '/after/plugin/completion.lua')
	local fallback_calls = 0
	vim.keymap.set('i', '<CR>', function()
		fallback_calls = fallback_calls + 1
		return '<C-]><CR>'
	end, { expr = true })
	vim.api.nvim_exec_autocmds('VimEnter', { group = 'NativeCompletion' })
	local enter = mapping '<CR>'
	override(vim.fn, { pumvisible = function() return 0 end }, function()
		assert(enter() == '<C-]><CR>')
	end)
	override(vim.fn, {
		pumvisible = function() return 1 end,
		complete_info = function() return { selected = 0 } end,
	}, function()
		assert(enter() == '<C-y>')
	end)
	assert(fallback_calls == 1, 'selected completion must bypass the late fallback')
end)

test('returns an existing expression RHS unchanged as fallback', function()
	vim.keymap.set('i', '<CR>', 'ExistingEnter()', { expr = true })
	dofile(vim.fn.getcwd() .. '/after/plugin/completion.lua')
	vim.api.nvim_exec_autocmds('VimEnter', { group = 'NativeCompletion' })
	override(vim.fn, { pumvisible = function() return 0 end }, function()
		assert(mapping('<CR>')() == 'ExistingEnter()')
	end)
end)

test('accepts only a selected completion candidate', function()
	load_completion()
	local enter = mapping '<CR>'
	local right = mapping '<Right>'

	override(vim.fn, {
		pumvisible = function()
			return 1
		end,
		complete_info = function()
			return { selected = 0 }
		end,
	}, function()
		assert(enter() == '<C-y>')
		assert(right() == '<C-y>')
	end)

	override(vim.fn, {
		pumvisible = function()
			return 1
		end,
		complete_info = function()
			return { selected = -1 }
		end,
	}, function()
		assert(enter() == '<CR>')
		assert(right() == '<Right>')
	end)

	override(vim.fn, {
		pumvisible = function()
			return 0
		end,
		complete_info = function()
			error 'complete_info must not be called without a popup'
		end,
	}, function()
		assert(enter() == '<CR>')
		assert(right() == '<Right>')
	end)
end)

test('triggers completion manually with control-space', function()
	load_completion()
	local trigger = mapping('<C-Space>', false)
	local called = false

	override(vim.lsp.completion, {
		get = function()
			called = true
		end,
	}, function()
		trigger()
	end)

	assert(called)
end)

test('uses omnifunc completion without a second automatic trigger', function()
	local completion = load_completion()
	local bufnr = vim.api.nvim_create_buf(true, false)
	vim.bo[bufnr].omnifunc = 'CustomComplete'
	local client = {
		id = 42,
		server_capabilities = {
			completionProvider = {
				triggerCharacters = { '.', 'λ', '.' },
			},
		},
		supports_method = function(_, method)
			return method == 'textDocument/completion'
		end,
	}
	local enable_args

	override(vim.lsp.completion, {
		enable = function(...)
			enable_args = { ... }
		end,
	}, function()
		assert(completion.attach(client, bufnr))
	end)

	assert(vim.deep_equal({ unpack(enable_args, 1, 3) }, { true, 42, bufnr }))
	assert(enable_args[4].autotrigger == false)
	assert(type(enable_args[4].convert) == 'function')
	assert(vim.bo[bufnr].omnifunc == 'CustomComplete')
	assert(vim.deep_equal(client.server_capabilities.completionProvider.triggerCharacters, { '.', 'λ', '.' }))
	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test('does not enable completion for unsupported clients', function()
	local completion = load_completion()
	local client = {
		id = 42,
		server_capabilities = {},
		supports_method = function()
			return false
		end,
	}
	local called = false

	override(vim.lsp.completion, {
		enable = function()
			called = true
		end,
	}, function()
		assert(not completion.attach(client, 7))
	end)

	assert(not called)
end)

test('registers completion setup for LSP attachments', function()
	load_completion()
	local autocmds = vim.api.nvim_get_autocmds {
		event = 'LspAttach',
		group = 'NativeCompletion',
	}
	assert(#autocmds == 1)
end)

test('previews and accepts includes without duplicating the existing delimiter', function()
	local completion = load_completion()
	local cases = {
		{ line = '#include ""', word = 'util.h"', col = 10, ending = '<CR>', expected = '#include "util.h"' },
		{ line = '#include "u"', word = 'util.h"', col = 11, ending = '<Right>', expected = '#include "util.h"' },
		{ line = '#include <>', word = 'util.h>', col = 10, ending = '<C-y>', expected = '#include <util.h>' },
		{ line = '#include "u"', word = 'util.h"', col = 11, ending = '<C-e>', expected = '#include "u"' },
		{ line = '#include "u', word = 'util.h"', col = 11, ending = '<C-y>', expected = '#include "util.h"' },
	}
	for _, case in ipairs(cases) do
		vim.cmd.enew()
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { case.line })
		local item = {
			label = case.word,
			textEdit = {
				newText = case.word,
				range = { start = { line = 0, character = 10 }, ['end'] = { line = 0, character = #case.line } },
			},
		}
		local original = vim.deepcopy(item)
		local client = {
			id = 42,
			offset_encoding = 'utf-16',
			capabilities = {},
			server_capabilities = { completionProvider = {} },
			supports_method = function(_, method)
				return method == 'textDocument/completion'
			end,
			request = function(_, _, _, callback)
				callback(nil, { item })
				return true, 1
			end,
			_get_registrations = function()
				return {}
			end,
			cancel_request = function() end,
		}
		local preview, menu
		override(vim.lsp, {
			get_client_by_id = function()
				return client
			end,
		}, function()
			assert(completion.attach(client, 0))
			vim.keymap.set('i', '<F6>', vim.lsp.completion.get, { desc = 'Test LSP completion' })
			vim.keymap.set('i', '<F7>', function()
				preview = vim.api.nvim_get_current_line()
				menu = vim.fn.complete_info().items[1].abbr
			end, { desc = 'Capture completion preview for test' })
			-- Enter insert mode immediately before the existing closing delimiter.
			vim.api.nvim_win_set_cursor(0, { 1, math.min(case.col, #case.line - 1) })
			local insert = case.col == #case.line and 'a' or 'i'
			vim.fn.feedkeys(insert .. vim.keycode('<F6><Tab><F7>' .. case.ending .. '<Esc>'), 'xt')
			vim.lsp.completion.enable(false, client.id, 0)
		end)
		vim.keymap.del('i', '<F6>')
		vim.keymap.del('i', '<F7>')
		assert(preview == '#include ' .. case.line:sub(10, 10) .. case.word, vim.inspect { case, preview })
		assert(menu == case.word, 'the menu must retain the original label')
		assert(vim.api.nvim_get_current_line() == case.expected, vim.inspect { case, vim.api.nvim_get_current_line() })
		assert(vim.deep_equal(item, original), 'conversion must preserve the LSP item')
		vim.bo.modified = false
	end
end)

test('keeps snippets and nonmatching closing characters unchanged', function()
	local completion = load_completion()
	local convert
	local client = {
		id = 42,
		server_capabilities = { completionProvider = {} },
		supports_method = function()
			return true
		end,
	}
	override(vim.lsp.completion, {
		enable = function(_, _, _, opts)
			convert = opts.convert
		end,
	}, function()
		completion.attach(client, 0)
	end)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { '#include ""' })
	vim.api.nvim_win_set_cursor(0, { 1, 10 })
	assert(vim.deep_equal(convert { label = 'util.h>', insertText = 'util.h>' }, {}))
	assert(vim.deep_equal(
		convert {
			label = 'util.h"',
			insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
			textEdit = { newText = 'util.h"$0' },
		},
		{}
	))
	vim.bo.modified = false
end)

if #failures > 0 then
	error(table.concat(failures, '\n'))
end
