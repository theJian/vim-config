-- markdown preview
vim.g.markdown_composer_autostart = 0
vim.pack.use {
	from = 'https://github.com/euclio/vim-markdown-composer',
	build = { 'cargo', 'build', '--release', '--locked' },
}
