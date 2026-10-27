vim.cmd.packadd 'nvim.undotree'
vim.pack.load 'https://github.com/norcalli/nvim-colorizer.lua'
	.using 'colorizer'
	.setup()
vim.pack.load 'https://github.com/kylechui/nvim-surround.git'
	.using 'nvim-surround'
	.setup()
vim.pack.load 'https://github.com/julienvincent/nvim-paredit.git'
	.using 'nvim-paredit'
	.setup()
vim.pack.load 'https://github.com/gpanders/nvim-parinfer.git'
vim.pack.load 'https://github.com/L3MON4D3/LuaSnip'
vim.pack.load 'https://github.com/bfredl/nvim-luadev'
vim.pack.load 'https://github.com/tpope/vim-fugitive.git'
require 'plugins.netrw'
require 'plugins.lsp'
require 'plugins.mason'
require 'plugins.pairs'
require 'plugins.completion'
require 'plugins.treesitter'
require 'plugins.dap'
require 'plugins.lint'
require 'plugins.formatter'
require 'plugins.lualine'
require 'plugins.fff'
require 'plugins.gitsigns'
require 'plugins.slimv'
require 'plugins.diagnostics'
require 'plugins.ibl'
require 'plugins.oil'
require 'plugins.grug-far'
require 'plugins.live-command'
require 'plugins.parinfer-rust'

-- markdown preview
vim.g.markdown_composer_autostart = 0
vim.pack.load 'https://github.com/euclio/vim-markdown-composer'
	.build { 'cargo', 'build', '--release', '--locked' }
