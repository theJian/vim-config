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

-- LSP items may be meant to replace text past the cursor. Clangd's include
-- completion, e.g. `#include "u|"` offers `util.h"`, with a textEdit that
-- replaces `u"` (the closing quote included). The popup can only insert up to
-- the cursor, so the closing char would be duplicated (`util.h""`). Drop it on
-- accept to keep completion pair-aware.
local closing_chars = { ['"'] = true, ["'"] = true, ['`'] = true, [')'] = true, [']'] = true, ['}'] = true, ['>'] = true }

vim.api.nvim_create_autocmd('CompleteDone', {
	group = vim.api.nvim_create_augroup('PairAwareCompletion', { clear = true }),
	desc = 'Drop closing char duplicated by accepting a completion',
	callback = function()
		if vim.v.event.reason ~= 'accept' then
			return
		end
		local item = vim.v.completed_item
		local lsp_item = vim.tbl_get(item, 'user_data', 'nvim', 'lsp', 'completion_item')
		-- snippets apply their full textEdit on their own
		if not lsp_item or lsp_item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet then
			return
		end
		local tail = (item.word or ''):sub(-1)
		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
		if closing_chars[tail] and line:sub(col + 1, col + 1) == tail then
			vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col + 1, { '' })
		end
	end,
})

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
