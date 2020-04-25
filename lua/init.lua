local api = vim.api

if api.nvim_get_option('loadplugins') then
	require 'packman'
	local lsp = require 'nvim_lsp'
	lsp.tsserver.setup{}
	lsp.gopls.setup{}
end
