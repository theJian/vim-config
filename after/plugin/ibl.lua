vim.pack.use { 'ibl', from = 'https://github.com/lukas-reineke/indent-blankline.nvim' }.setup {
	indent = {
		char = '┊',
	},
	scope = {
		char = '│',
		show_start = false,
		show_end = false,
	}
}
