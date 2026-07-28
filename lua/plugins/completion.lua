local M = {}

vim.opt.completeopt = { 'fuzzy', 'menuone', 'noselect', 'popup' }

local function trigger_characters(server_characters)
	local characters = {}
	local seen = {}

	local function add(character)
		if not seen[character] then
			table.insert(characters, character)
			seen[character] = true
		end
	end

	for _, character in ipairs(server_characters or {}) do
		add(character)
	end
	for codepoint = 32, 126 do
		add(string.char(codepoint))
	end
	add '\n'
	add '\t'

	return characters
end

local function key_fallback(lhs)
	local mapping = vim.fn.maparg(lhs, 'i', false, true)
	if mapping.expr == 1 then
		if type(mapping.callback) == 'function' then
			return mapping.callback
		end
		if mapping.rhs and mapping.rhs ~= '' then
			return function()
				return mapping.rhs
			end
		end
	end
	return function()
		return lhs
	end
end

local function confirm_completion(fallback)
	if vim.fn.pumvisible() ~= 1 or vim.fn.complete_info().selected == -1 then
		return fallback()
	end
	return '<C-y>'
end

local enter_fallback = key_fallback '<CR>'
local right_fallback = key_fallback '<Right>'

function M.attach(client, bufnr)
	if not client:supports_method 'textDocument/completion' then
		return false
	end

	local provider = client.server_capabilities.completionProvider
	if not provider then
		return false
	end

	provider.triggerCharacters = trigger_characters(provider.triggerCharacters)
	vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
	return true
end

vim.keymap.set({ 'i', 's' }, '<Tab>', function()
	if vim.fn.pumvisible() == 1 then
		return '<C-n>'
	end
	if vim.snippet.active { direction = 1 } then
		return '<Cmd>lua vim.snippet.jump(1)<CR>'
	end
	return '<Tab>'
end, { desc = 'Select next completion or snippet tabstop', expr = true, silent = true })

vim.keymap.set({ 'i', 's' }, '<S-Tab>', function()
	if vim.fn.pumvisible() == 1 then
		return '<C-p>'
	end
	if vim.snippet.active { direction = -1 } then
		return '<Cmd>lua vim.snippet.jump(-1)<CR>'
	end
	return '<S-Tab>'
end, { desc = 'Select previous completion or snippet tabstop', expr = true, silent = true })

vim.keymap.set('i', '<CR>', function()
	return confirm_completion(enter_fallback)
end, { desc = 'Accept selected completion', expr = true, silent = true })

vim.keymap.set('i', '<Right>', function()
	return confirm_completion(right_fallback)
end, { desc = 'Accept selected completion', expr = true, silent = true })

vim.keymap.set('i', '<C-Space>', function()
	vim.lsp.completion.get()
end, { desc = 'Trigger LSP completion' })

vim.api.nvim_create_autocmd('LspAttach', {
	group = vim.api.nvim_create_augroup('NativeCompletion', { clear = true }),
	desc = 'Enable native LSP completion',
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client then
			M.attach(client, ev.buf)
		end
	end,
})

return M
