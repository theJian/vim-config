vim.lsp.set_log_level 'WARN'
require('vim.lsp.log').set_format_func(vim.inspect)
local capabilities = require('cmp_nvim_lsp').default_capabilities()

vim.lsp.config('*', {
	capabilities = capabilities,
	root_markers = { '.git' },
})

vim.lsp.enable 'lua_ls'
vim.lsp.config('lua_ls', {
	settings = {
		Lua = {
			runtime = {
				-- Tell the language server which version of Lua you're using
				-- (most likely LuaJIT in the case of Neovim)
				version = 'LuaJIT',
			},
			diagnostics = {
				-- Get the language server to recognize the `vim` global
				globals = {
					'vim',
					'require',
				},
			},
			workspace = {
				-- Make the server aware of Neovim runtime files
				library = vim.api.nvim_get_runtime_file('', true),
			},
			-- Do not send telemetry data containing a randomized but unique identifier
			telemetry = {
				enable = false,
			},
		},
	},
})
vim.lsp.enable 'rust_analyzer'
vim.lsp.config('rust_analyzer', {
	settings = {
		['rust-analyzer'] = {
			imports = {
				granularity = {
					group = 'module',
				},
				prefix = 'self',
			},
			cargo = {
				buildScripts = {
					enable = true,
				},
			},
			procMacro = {
				enable = true,
			},
		},
	},
})
vim.lsp.enable 'bashls'
vim.lsp.enable 'ts_ls'
vim.lsp.enable 'jsonls'
vim.lsp.enable 'cssls'
vim.lsp.enable 'gopls'
vim.lsp.enable 'pyrefly'
vim.lsp.enable 'ruff'

-- vim.lsp.enable 'basedpyright'
-- vim.lsp.config('basedpyright', {
-- 	settings = {
-- 		basedpyright = {
-- 			disableOrganizeImports = true,
-- 			analysis = {
-- 				ignore = { '*' },
-- 			},
-- 		},
-- 	},
-- })

vim.lsp.enable 'fennel_ls'

vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(ev)
		local opts = { buffer = ev.buf }
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
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

		if client:supports_method 'textDocument/documentHighlight' then
			vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
				buffer = ev.buf,
				callback = vim.lsp.buf.document_highlight,
			})
		end

		vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
			buffer = ev.buf,
			callback = vim.lsp.buf.clear_references,
		})

		if client:supports_method 'textDocument/codeLens' then
			vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'InsertLeave' }, {
				buffer = ev.buf,
				callback = vim.lsp.codelens.refresh,
			})
		end

		if client:supports_method 'textDocument/inlayHint' then
			vim.lsp.inlay_hint.enable(true)
		end
	end,
})
