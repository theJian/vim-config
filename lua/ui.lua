vim.o.termguicolors = true

-- Show invisiable chars
vim.o.list = true
vim.o.listchars = 'tab:┊ ,trail:∙,extends:…,nbsp:∙,precedes:…'

-- Alternative chars for special lines, separator, etc.
vim.o.fillchars = 'wbr:░,fold:,diff:'

-- Matches highlight delay
vim.o.showmatch = true
vim.o.matchtime = 3

-- Statusline
vim.o.laststatus = 3 -- always and ONLY the last window
-- vim.opt.statusline = '%(%2*%{fnamemodify(expand("%"),":.")}%a⧹%*%)' -- file path
vim.opt.statusline:append '%(%R%H%W⧹%) ' -- file info
vim.opt.statusline:append '%(%{&modified?" ●":""}⧹%)' -- modified flag
vim.opt.statusline:append '%=' -- switch to the right side
vim.opt.statusline:append '∕%4l:%-3c' -- cursor position
vim.opt.statusline:append '∕%<%3p%%' -- scroll position
vim.opt.statusline:append '%(∕%Y%)' -- file type

-- Winbar
vim.opt.winbar = '%f'

-- Colorscheme
if
	not pcall(function()
		require('moonwalk').setup {
			-- transparent = true
		}
		vim.o.background = 'light'
		vim.cmd.colorscheme 'moonwalk'
	end)
then
	vim.api.nvim_echo({ { 'missing colorscheme' } }, true, { err = true })
end

-- Mimium number of screen lines to keep above or below the cursor
vim.o.scrolloff = 3

-- Scroll faster by scrolling more lines at a time
vim.o.scrolljump = 3

-- scroll by screen line rather than by text line
vim.o.smoothscroll = true

-- Highlight cursor line number
vim.wo.cursorline = true
vim.wo.cursorlineopt = 'both'

-- Use relative number
vim.wo.number = true
vim.wo.relativenumber = true

-- Clear highlight above 180 characters width
vim.o.synmaxcol = 180

-- Wrapped line mark
vim.o.showbreak = '↪  '

-- Show message in insert
vim.o.showmode = true

-- Always show sign column
vim.wo.signcolumn = 'yes:2'
vim.o.inccommand = 'nosplit'

-- Popup menu height
vim.o.pumheight = 5
