-- vim.lsp.set_log_level 'trace'
if vim.fn.has 'nvim-0.5.1' == 1 then
	require('vim.lsp.log').set_format_func(vim.inspect)
end
local lsp = require'lspconfig'
local capabilities = require('cmp_nvim_lsp').default_capabilities()

local function lsp_setup(target, options)
	options = options or {}
	options.capabilities = capabilities
	lsp[target].setup(options)
end
lsp_setup('lua_ls', {
	settings = {
		Lua = {
			runtime = {
				version = 'LuaJIT',
			},
			diagnostics = {
				globals = {'vim'},
			},
			workspace = {
				library = vim.api.nvim_get_runtime_file('', true),
			},
		},
	},
})
lsp_setup('rust_analyzer', {
	on_attach = function(client, bufnr)
		vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
	end,
	settings = {
		["rust-analyzer"] = {
			imports = {
				granularity = {
					group = "module",
				},
				prefix = "self",
			},
			cargo = {
				buildScripts = {
					enable = true,
				},
			},
			procMacro = {
				enable = true
			},
		}
	}
})
lsp_setup('bashls')
lsp_setup('ts_ls')
lsp_setup('jsonls')
lsp_setup('cssls')
lsp_setup('gopls', {
	cmd = { vim.fn.trim(vim.fn.system('go env GOPATH')) .. "/bin/gopls" };
})
lsp_setup('basedpyright', {
	settings = {
		basedpyright = {
			disableOrganizeImports = true,
			analysis = {
				ignore = { '*' }
			}
		}
	}
})
lsp_setup('ruff')
lsp_setup('fennel_ls')

vim.api.nvim_create_autocmd('LspAttach', {
	callback = function (ev)
		local opts = { buffer = ev.buf }
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		vim.keymap.set('n', 'gK', function()
			local new_config = not vim.diagnostic.config().virtual_lines
			vim.diagnostic.config({ virtual_lines = new_config })
		end, opts)

		vim.keymap.set('n', 'g0', vim.diagnostic.setloclist)

		-- vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
		-- vim.keymap.set('n', ']d', vim.diagnostic.goto_next)

		vim.keymap.set('n', 'gs', vim.lsp.buf.signature_help, opts)
      vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
      -- vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
      vim.keymap.set('n', 'gI', vim.lsp.buf.implementation, opts)
      vim.keymap.set('n', '<leader>wn', vim.lsp.buf.add_workspace_folder, opts)
      vim.keymap.set('n', '<leader>wd', vim.lsp.buf.remove_workspace_folder, opts)
      vim.keymap.set('n', '<leader>wl', function()
        vim.print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, opts)
      vim.keymap.set('n', 'gy', vim.lsp.buf.type_definition, opts)
      vim.keymap.set('n', 'gR', vim.lsp.buf.rename, opts)
      vim.keymap.set({ 'n', 'v' }, 'g.', vim.lsp.buf.code_action, opts)
      vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
      vim.keymap.set('n', 'gO', vim.lsp.buf.document_symbol, opts)
      vim.keymap.set('n', '<leader>fm', function()
        vim.lsp.buf.format { async = true }
      end, opts)

		if client.server_capabilities.documentHighlightProvider then
			vim.api.nvim_create_autocmd({'CursorHold', 'CursorHoldI'}, {
				buffer = ev.buf,
				callback = vim.lsp.buf.document_highlight,
			})
		end

		vim.api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
			buffer = ev.buf,
			callback = vim.lsp.buf.clear_references,
		})

		if client.server_capabilities.codeLensProvider then
			vim.api.nvim_create_autocmd({'BufEnter', 'CursorHold', 'InsertLeave'}, {
				buffer = ev.buf,
				callback = vim.lsp.codelens.refresh,
			})
		end

	end
})


