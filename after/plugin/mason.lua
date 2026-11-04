vim.pack.use { 'mason', from = 'https://github.com/williamboman/mason.nvim' }.setup()
vim.pack.use { 'mason-lspconfig', from = 'https://github.com/williamboman/mason-lspconfig.nvim' }.setup {
	automatic_installation = true,
	ensure_installed = {}
}

