vim.pack.load 'https://github.com/lukas-reineke/indent-blankline.nvim'
	.using 'ibl'
	.setup {
		indent = {
			char = '┊',
		},
		scope = {
			char = '│',
			show_start = false,
			show_end = false,
		}
	}
