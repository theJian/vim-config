local api = vim.api
local fn = vim.fn

if api.nvim_get_option('loadplugins') then
	require 'packman'
	local lsp = require 'nvim_lsp'
	lsp.tsserver.setup{}
	lsp.jsonls.setup{}
	lsp.cssls.setup{}
	lsp.gopls.setup{
		cmd = { fn.trim(fn.system('go env GOPATH')) .. "/bin/gopls" };
	}
end
