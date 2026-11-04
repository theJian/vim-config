-- Configure native LSP servers and buffer attachment behavior during native
-- plugin startup after prelude installs the table-based vim.pack API; nvim-lspconfig
-- supplies server defaults alongside local lsp/*.lua configs. Server executables
-- must be installed separately. LspAttach installs buffer mappings once and requests
-- reference highlights on normal-mode idle, discarding responses after context changes.
vim.pack.add { 'https://github.com/neovim/nvim-lspconfig.git' }

vim.lsp.log.set_level 'WARN'
require('vim.lsp.log').set_format_func(vim.inspect)

vim.lsp.enable 'emmylua_ls'
vim.lsp.enable 'rust_analyzer'
vim.lsp.enable 'bacon_ls'
vim.lsp.enable 'bashls'
vim.lsp.enable 'tsc'
vim.lsp.enable 'jsonls'
vim.lsp.enable 'cssls'
vim.lsp.enable 'gopls'
vim.lsp.enable 'pyrefly'
vim.lsp.enable 'ruff'
vim.lsp.enable 'fennel_ls'
vim.lsp.enable 'quick_lint_js'
vim.lsp.enable 'c3_lsp'
vim.lsp.enable 'ols'


vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(ev)
		if not vim.b[ev.buf].keymaps_set then
			vim.keymap.set('n', 'gK', function()
				local new_config = not vim.diagnostic.config().virtual_lines
				vim.diagnostic.config { virtual_lines = new_config }
			end, { buffer = ev.buf, desc = 'Toggle diagnostic virtual lines' })

			-- vim.keymap.set('n', 'grx', vim.lsp.codelens.run, { buffer = ev.buf, desc = 'Run code lens' })

			vim.keymap.set(
				'n',
				'g0',
				vim.diagnostic.setloclist,
				{ buffer = ev.buf, desc = 'Show diagnostics in location list' }
			)

			-- vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic' })
			-- vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic' })

			vim.keymap.set('n', 'gs', vim.lsp.buf.signature_help, { buffer = ev.buf, desc = 'Show signature help' })
			vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, { buffer = ev.buf, desc = 'Go to declaration' })
			vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = ev.buf, desc = 'Go to definition' })
			vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = ev.buf, desc = 'Show hover documentation' })
			-- vim.keymap.set('n', 'gri', vim.lsp.buf.implementation, { buffer = ev.buf, desc = 'Go to implementation' })
			vim.keymap.set(
				'n',
				'<leader>wn',
				vim.lsp.buf.add_workspace_folder,
				{ buffer = ev.buf, desc = 'Add workspace folder' }
			)
			vim.keymap.set(
				'n',
				'<leader>wd',
				vim.lsp.buf.remove_workspace_folder,
				{ buffer = ev.buf, desc = 'Remove workspace folder' }
			)
			vim.keymap.set('n', '<leader>wL', function()
				vim.print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
			end, { buffer = ev.buf, desc = 'List workspace folders' })
			-- vim.keymap.set('n', 'grt', vim.lsp.buf.type_definition, { buffer = ev.buf, desc = 'Go to type definition' })
			-- vim.keymap.set('n', 'grn', vim.lsp.buf.rename, { buffer = ev.buf, desc = 'Rename symbol' })
			-- vim.keymap.set({ 'n', 'v' }, 'gra', vim.lsp.buf.code_action, { buffer = ev.buf, desc = 'Code action' })
			-- vim.keymap.set('n', 'grr', vim.lsp.buf.references, { buffer = ev.buf, desc = 'List references' })
			-- vim.keymap.set('n', 'gO', vim.lsp.buf.document_symbol, { buffer = ev.buf, desc = 'List document symbols' })
			vim.keymap.set('n', 'grh', function()
				local bufnr = ev.buf
				local current = vim.lsp.inlay_hint.is_enabled { bufnr = bufnr }
				vim.lsp.inlay_hint.enable(not current, { bufnr = bufnr })
			end, { buffer = ev.buf, desc = 'Toggle inlay hints' })
			vim.b[ev.buf].keymaps_set = true
		end

		local highlight_method = vim.lsp.protocol.Methods.textDocument_documentHighlight
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client and client:supports_method(highlight_method) and not vim.b[ev.buf].reference_highlights_set then
			local bufnr = ev.buf
			-- A generation rejects stale responses even after cursor or mode returns to its original state.
			local generation = 0
			vim.api.nvim_create_autocmd('CursorHold', {
				buffer = bufnr,
				callback = function()
					if
						vim.api.nvim_get_mode().mode ~= 'n'
						or #vim.lsp.get_clients { bufnr = bufnr, method = highlight_method } == 0
					then
						return
					end
					generation = generation + 1
					local request_generation = generation
					local win = vim.api.nvim_get_current_win()
					local cursor = vim.api.nvim_win_get_cursor(win)
					local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
					vim.lsp.buf_request(bufnr, highlight_method, function(request_client)
						return vim.lsp.util.make_position_params(win, request_client.offset_encoding)
					end, function(err, result, ctx)
						if
							err
							or not result
							or generation ~= request_generation
							or vim.api.nvim_get_mode().mode ~= 'n'
							or not vim.api.nvim_buf_is_valid(bufnr)
							or vim.api.nvim_get_current_buf() ~= bufnr
							or vim.api.nvim_get_current_win() ~= win
							or not vim.deep_equal(vim.api.nvim_win_get_cursor(win), cursor)
							or vim.api.nvim_buf_get_changedtick(bufnr) ~= changedtick
						then
							return
						end
						local response_client = vim.lsp.get_client_by_id(ctx.client_id)
						if response_client and vim.lsp.buf_is_attached(bufnr, ctx.client_id) then
							vim.lsp.util.buf_highlight_references(bufnr, result, response_client.offset_encoding)
						end
					end)
				end,
			})

			vim.api.nvim_create_autocmd(
				{ 'CursorMoved', 'ModeChanged', 'BufLeave', 'WinLeave', 'TextChanged', 'TextChangedI' },
				{
					buffer = bufnr,
					callback = function()
						generation = generation + 1
						vim.lsp.util.buf_clear_references(bufnr)
					end,
				}
			)
			vim.b[ev.buf].reference_highlights_set = true
		end

		-- if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
		-- 	vim.lsp.inlay_hint.enable(true)
		-- end
	end,
})
