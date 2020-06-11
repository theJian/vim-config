local api = vim.api
local fn = vim.fn

if api.nvim_get_option('loadplugins') then
	require 'packman'

	local homedir = vim.loop.os_homedir()
	local lsp = require 'nvim_lsp'
	lsp.vimls.setup{}
	lsp.rust_analyzer.setup{}
	lsp.pyls_ms.setup{
		cmd = { "dotnet", "exec", homedir .. "/bin/languageServer/pyls_ms/Microsoft.Python.LanguageServer.dll" };
	}
	lsp.bashls.setup{}
	lsp.tsserver.setup{}
	lsp.jsonls.setup{}
	lsp.cssls.setup{}
	lsp.gopls.setup{
		cmd = { fn.trim(fn.system('go env GOPATH')) .. "/bin/gopls" };
	}

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
	fit_find('<leader>d', fit_repos, 'lcd')
	fit_buffers('<leader>b')
end
