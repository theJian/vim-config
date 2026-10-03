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
	package.loaded['plugins.completion'] = nil
	return require 'plugins.completion'
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
	for name, original in pairs(originals) do
		target[name] = original
	end
	assert(ok, result)
	return result
end

test('enables fuzzy completion without disabling fuzzy sorting', function()
	load_completion()
	assert(vim.deep_equal(vim.opt.completeopt:get(), { 'fuzzy', 'menuone', 'noselect', 'popup' }))
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
	end, { expr = true })

	package.loaded['plugins.completion'] = nil
	require 'plugins.completion'
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

test('enables autotrigger with fuzzy-friendly trigger characters', function()
	local completion = load_completion()
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
		assert(completion.attach(client, 7))
	end)

	assert(vim.deep_equal({ unpack(enable_args, 1, 3) }, { true, 42, 7 }))
	assert(enable_args[4].autotrigger == true)
	assert(type(enable_args[4].convert) == 'function')

	local triggers = client.server_capabilities.completionProvider.triggerCharacters
	local counts = {}
	for _, character in ipairs(triggers) do
		counts[character] = (counts[character] or 0) + 1
	end

	for codepoint = 32, 126 do
		assert(counts[string.char(codepoint)] == 1, 'missing or duplicate printable trigger ' .. codepoint)
	end
	assert(counts['\n'] == 1)
	assert(counts['\t'] == 1)
	assert(counts['λ'] == 1)
	assert(#triggers == 98)
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
			server_capabilities = { completionProvider = {} },
			supports_method = function(_, method)
				return method == 'textDocument/completion'
			end,
			request = function(_, _, _, callback)
				callback(nil, { item })
				return true, 1
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
			vim.keymap.set('i', '<F6>', vim.lsp.completion.get)
			vim.keymap.set('i', '<F7>', function()
				preview = vim.api.nvim_get_current_line()
				menu = vim.fn.complete_info().items[1].abbr
			end)
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
