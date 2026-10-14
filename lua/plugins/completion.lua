local M = {}

vim.opt.completeopt = { 'fuzzy', 'menuone', 'noselect', 'popup' }
-- Use one trigger for LSP and buffer words, with LSP as the first source.
vim.opt.complete:prepend 'o'

local completion_group = vim.api.nvim_create_augroup('NativeCompletion', { clear = true })

vim.bo.autocomplete = vim.bo.buftype == ''
vim.api.nvim_create_autocmd({ 'BufEnter', 'TermOpen' }, {
	group = completion_group,
	desc = 'Enable autocomplete only in normal buffers',
	callback = function()
		vim.bo.autocomplete = vim.bo.buftype == ''
	end,
})
vim.api.nvim_create_autocmd('OptionSet', {
	group = completion_group,
	pattern = 'buftype',
	desc = 'Update autocomplete when the buffer type changes',
	callback = function()
		vim.bo.autocomplete = vim.bo.buftype == ''
	end,
})

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

local closing_chars = {
	['"'] = true,
	["'"] = true,
	['`'] = true,
	[')'] = true,
	[']'] = true,
	['}'] = true,
	['>'] = true,
}

local function pair_aware_completion(item)
	local kind = vim.lsp.protocol.CompletionItemKind[item.kind]
	local result = kind and kind ~= 'Color' and { kind_hlgroup = 'LspKind' .. kind } or {}
	-- Snippets apply their own textEdit when accepted.
	if item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet then
		return result
	end
	local word = item.textEdit and item.textEdit.newText
		or (item.insertText and item.insertText ~= '' and item.insertText)
		or item.label
	word = word:match '[^\r\n]*'
	local tail = word:sub(-1)
	local col = vim.api.nvim_win_get_cursor(0)[2]
	-- Native completion only replaces up to the cursor, including during preview.
	if closing_chars[tail] and vim.api.nvim_get_current_line():sub(col + 1, col + 1) == tail then
		result.word = word:sub(1, -2)
	end
	return result
end

function M.attach(client, bufnr)
	if not client:supports_method 'textDocument/completion' then
		return false
	end

	local provider = client.server_capabilities.completionProvider
	if not provider then
		return false
	end

	vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = false, convert = pair_aware_completion })
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
	group = completion_group,
	desc = 'Enable native LSP completion',
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client then
			M.attach(client, ev.buf)
		end
	end,
})

return M
