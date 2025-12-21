-- Mouse
vim.o.mouse = 'nc'

-- Compatible options
vim.opt.cpoptions:append 'n'
vim.opt.cpoptions:append 'y'
vim.opt.cpoptions:remove ';'

-- Tab
vim.o.softtabstop = 4
vim.o.tabstop = 4
vim.o.shiftwidth = 4

-- Open new splits on the right/bottom
vim.o.splitbelow = true
vim.o.splitright = true

-- Hide changed buffer instead close
vim.o.hidden = true

-- Good performance
vim.o.lazyredraw = true

-- Searching
vim.o.ignorecase = true
vim.o.smartcase = true

-- Explore files case-insensitively
vim.o.wildignorecase = true

-- Folding
vim.wo.foldenable = true
vim.o.foldlevelstart = 6
vim.wo.foldnestmax = 10
vim.wo.foldmethod = 'expr'
vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.opt.foldopen:remove 'block'

-- File format
vim.o.fileformat = 'unix'

-- Wrap long lines
vim.o.wrap = true
vim.o.linebreak = true

-- No backup files, no swap files
vim.o.backup = false
vim.o.swapfile = false

-- Allow cursor to move just past the end of the line
vim.o.virtualedit = 'block,onemore'

-- Ask confirmation for certain things like when quitting before saving
vim.o.confirm = true

-- Turn off bell
vim.o.visualbell = false
vim.o.errorbells = false

-- Search stop at the end of file
vim.o.wrapscan = false

-- Yank text to system clipboard
if string.find(vim.loop.os_uname().sysname, 'Darwin') then
	vim.opt.clipboard:append 'unnamedplus'
end

-- Persistent undo
vim.o.undofile = true

-- Browser like jumplist
vim.o.jumpoptions = 'view'

-- Complete
vim.o.completeopt = 'fuzzy,menu,menuone,popup,noinsert'

-- Default shell
vim.o.shell = 'nu'

-- Control how often lualine updates
vim.o.updatetime = 30

-- Enable spell check
vim.opt.spelllang = 'en_us'
vim.opt.spell = true

-- Disable showing mode like -- INSERT -- or -- VISUAL --
vim.o.showmode = false
