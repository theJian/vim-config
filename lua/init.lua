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
end
