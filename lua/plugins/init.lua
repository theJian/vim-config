require 'packman'
require('colorizer').setup()
require('nvim-surround').setup()
require('nvim-paredit').setup()
require 'plugins.netrw'
require 'plugins.mason'
require 'plugins.lsp'
require 'plugins.dap'
require 'plugins.lint'
require 'plugins.formatter'
require 'plugins.lualine'
require 'plugins.fit'
require 'plugins.gitsigns'
require 'plugins.slimv'
require 'plugins.diagnostics'
require 'plugins.ibl'
require 'plugins.treesitter'
require 'plugins.oil'
require 'plugins.grug-far'
require 'plugins.live-command'
require 'plugins.blink'
require 'plugins.pairs'

-- markdown preview
vim.g.markdown_composer_autostart = 0
