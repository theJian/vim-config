vim.lsp.set_log_level 'WARN'
require('vim.lsp.log').set_format_func(vim.inspect)

vim.lsp.enable 'lua_ls'
vim.lsp.enable 'rust_analyzer'
vim.lsp.enable 'bashls'
vim.lsp.enable 'ts_ls'
vim.lsp.enable 'jsonls'
vim.lsp.enable 'cssls'
vim.lsp.enable 'gopls'
vim.lsp.enable 'pyrefly'
vim.lsp.enable 'ruff'
vim.lsp.enable 'fennel_ls'

vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(ev)
		if not vim.b[ev.buf].keymaps_set then
			local opts = { buffer = ev.buf }
			vim.keymap.set('n', 'gK', function()
				local new_config = not vim.diagnostic.config().virtual_lines
				vim.diagnostic.config { virtual_lines = new_config }
			end, opts)

			vim.keymap.set('n', 'g0', vim.diagnostic.setloclist)

			-- vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
			-- vim.keymap.set('n', ']d', vim.diagnostic.goto_next)

			vim.keymap.set('n', 'gs', vim.lsp.buf.signature_help, opts)
			vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
			vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
			vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
			-- vim.keymap.set('n', 'gri', vim.lsp.buf.implementation, opts)
			vim.keymap.set('n', '<leader>wn', vim.lsp.buf.add_workspace_folder, opts)
			vim.keymap.set('n', '<leader>wd', vim.lsp.buf.remove_workspace_folder, opts)
			vim.keymap.set('n', '<leader>wl', function()
				vim.print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
			end, opts)
			vim.keymap.set('n', 'gy', vim.lsp.buf.type_definition, opts)
			-- vim.keymap.set('n', 'grn', vim.lsp.buf.rename, opts)
			-- vim.keymap.set({ 'n', 'v' }, 'gra', vim.lsp.buf.code_action, opts)
			-- vim.keymap.set('n', 'grr', vim.lsp.buf.references, opts)
			-- vim.keymap.set('n', 'gO', vim.lsp.buf.document_symbol, opts)
			vim.keymap.set('n', 'grh', function()
				local bufnr = ev.buf
				local current = vim.lsp.inlay_hint.is_enabled { bufnr = bufnr }
				vim.lsp.inlay_hint.enable(not current, { bufnr = bufnr })
			end, opts)
			vim.b[ev.buf].keymaps_set = true
		end

		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
			vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
				buffer = ev.buf,
				callback = vim.lsp.buf.document_highlight,
			})
		end

		vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
			buffer = ev.buf,
			callback = vim.lsp.buf.clear_references,
		})

		if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_codeLens) then
			vim.api.nvim_create_autocmd({ 'BufEnter', 'InsertLeave' }, {
				buffer = ev.buf,
				callback = function()
					vim.lsp.codelens.refresh { bufnr = 0 }
				end,
			})
		end

		if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
			vim.lsp.inlay_hint.enable(true)
		end

		if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_completion) then
			vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
			vim.keymap.set('i', '<C-Space>', vim.lsp.completion.get)
		end
	end,
})
