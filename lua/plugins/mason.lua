vim.pack.load 'https://github.com/williamboman/mason.nvim'
	.using 'mason'
	.setup()
vim.pack.load 'https://github.com/williamboman/mason-lspconfig.nvim'
	.using 'mason-lspconfig'
	.setup {
		automatic_installation = true,
		ensure_installed = {}
	}

