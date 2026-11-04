-- Configure Blink pairing during native plugin startup; vim.pack.use completes
-- required Cargo builds before setup.
vim.pack.use {
	'blink.pairs',
	from = 'https://github.com/saghen/blink.pairs',
	build = { 'cargo', 'build', '--release', '--locked' },
}.setup {}
