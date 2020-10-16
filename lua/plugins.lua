local api = vim.api
local fn = vim.fn

if api.nvim_get_option('loadplugins') then
	require 'packman'

	local homedir = vim.loop.os_homedir()
	local lsp = require 'nvim_lsp'
	local function lsp_setup(target, options)
		options = options or {}
		options.on_attach = function()
			require'ntc'.setup{
				auto_popup = true,
				chain = { 'omni', 'curt' }
			}
		end
		lsp[target].setup(options)
	end
	lsp_setup('vimls')
	-- lsp_setup('vimscript-language-server')
	lsp_setup('rust_analyzer')
	lsp_setup('pyls_ms', {
		cmd = { "dotnet", "exec", homedir .. "/bin/languageServer/pyls_ms/Microsoft.Python.LanguageServer.dll" };
	})
	lsp_setup('bashls', {})
	lsp_setup('tsserver', {})
	lsp_setup('jsonls', {})
	lsp_setup('cssls', {})
	lsp_setup('gopls', {
		cmd = { fn.trim(fn.system('go env GOPATH')) .. "/bin/gopls" };
	})

	-- vim.g.completion_enable_snippet = 'UltiSnips'

	local function lsp_keymap(lhs, methodName)
		vim.api.nvim_set_keymap(
			'n',
			lhs,
			string.format(
				'<cmd>lua '..
				'if vim.tbl_isempty(vim.lsp.buf_get_clients()) then '..
					'vim.api.nvim_feedkeys("%s", "n", true) '..
				'else '..
					'vim.lsp.buf.%s() '..
				'end<CR>',
				lhs, methodName
			),
			{ unique = true, silent = true }
		)
	end

	lsp_keymap('gd',    'declaration')
	lsp_keymap('<c-]>', 'definition')
	lsp_keymap('K',     'hover')
	lsp_keymap('gD',    'implementation')
	lsp_keymap('gk',    'signature_help')
	lsp_keymap('gh',    'type_definition')
	lsp_keymap('gr',    'references')
	lsp_keymap('g0',    'document_symbol')

	local function fit_find(lhs, find_command, accept_command)
		local find_command_with_query = find_command .. '|fzy --show-matches=<query>|head -n 30'
		vim.api.nvim_set_keymap(
			'n',
			lhs,
			string.format(
				'<cmd>lua require("fit").find(%q, %q)<CR>',
				find_command_with_query, accept_command or 'e'
			),
			{ unique = true, silent = true }
		)
	end

	local function fit_buffers(lhs)
		vim.api.nvim_set_keymap(
			'n',
			lhs,
			'<cmd>lua require("fit").buffers("fzy --show-matches=<query>")<CR>',
			{ unique = true, silent = true }
		)
	end

	local fit_files = 'rg --color never --files <cwd>'
	local fit_current_dir_files = 'rg --color never --files <dir>'
	local fit_repos = 'find ~ -maxdepth 2 -type d -execdir test -d {}/.git \\; -print -prune'
	fit_find('<leader>f', fit_files)
	fit_find('<leader>e', fit_current_dir_files)
	fit_find('<leader>d', fit_repos, 'tcd')
	fit_buffers('<leader>b')
end
