vim.pack.load 'https://github.com/saghen/blink.pairs'
	.build { 'cargo', 'build', '--release', '--locked' }
	.using 'blink.pairs'
	.setup {}
