require'packman'
require'colorizer'.setup()
require'nvim-surround'.setup()
require("nvim-paredit").setup()
require'plugins.netrw'
require'plugins.mason'
require'plugins.cmp'
require'plugins.lsp'
require'plugins.lualine'
require'plugins.fit'
require'plugins.gitsigns'
require'plugins.slimv'
require'plugins.diagnostics'
require'plugins.ibl'
require'plugins.treesitter'
require'plugins.oil'
require'plugins.grug-far'

-- delimitMate
vim.g.delimitMate_expand_cr = 1
vim.g.delimitMate_expand_space = 1
vim.g.delimitMate_jump_expansion = 1
vim.g.delimitMate_excluded_regions = "Comment"
vim.g.delimitMate_excluded_ft = "md,lisp,clojure,scheme,racket,fennel"

-- markdown preview
vim.g.markdown_composer_autostart = 0
