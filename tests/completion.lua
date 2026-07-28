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

test('accepts only a selected completion item', function()
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

	assert(vim.deep_equal(enable_args, { true, 42, 7, { autotrigger = true } }))

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

if #failures > 0 then
	error(table.concat(failures, '\n'))
end
