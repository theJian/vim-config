local api = vim.api
local fn = vim.fn

if api.nvim_get_option('loadplugins') then
	require 'packman'

	ntc_options={ auto_popup = 1, chain = {'omni', 'incl', 'file', 'line'} }

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

	function lsp_keymap(lhs, methodName)
		vim.api.nvim_set_keymap(
			'n',
			lhs,
			string.format(
				'<cmd>lua '..
				'if vim.tbl_isempty(vim.lsp.buf_get_clients()) then '..
					'vim.api.nvim_command("normal! %s") '..
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
end
