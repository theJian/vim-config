local api = vim.api
local keymap = vim.keymap

-- General ---------------------------------------------------------------------

-- Mouse
vim.o.mouse = 'nc'

-- Compatible options
vim.opt.cpoptions:append('n')
vim.opt.cpoptions:append('y')
vim.opt.cpoptions:remove(';')

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
vim.wo.foldexpr = 'nvim_treesitter#foldexpr()'
vim.opt.foldopen:remove('block')

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
vim.opt.clipboard:append('unnamedplus')

-- Persistent undo
vim.o.undofile = true

-- Browser like jumplist
vim.o.jumpoptions = 'view'

-- Complete
-- vim.opt.completeopt:remove('preview')
-- vim.opt.completeopt:append('menuone')
-- vim.opt.completeopt:append('noselect')
vim.o.completeopt = 'menu,menuone,popup'

-- Default shell
vim.o.shell = 'nu'

-- Control how often lualine updates
vim.o.updatetime = 80

-- Enable spell check
vim.opt.spelllang = 'en_us'
vim.opt.spell = true


-- User Interface --------------------------------------------------------------

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
vim.opt.statusline:append('%(%R%H%W⧹%) ')                      -- file info
vim.opt.statusline:append('%(%{&modified?" ●":""}⧹%)')         -- modified flag
vim.opt.statusline:append('%=')                                     -- switch to the right side
vim.opt.statusline:append('∕%4l:%-3c')                         -- cursor position
vim.opt.statusline:append('∕%<%3p%%')                          -- scroll position
vim.opt.statusline:append('%(∕%Y%)')                           -- file type
-- api.nvim_create_autocmd('ColorScheme', {
--     pattern = '*',
--     callback = function()
--         api.nvim_set_hl(0, 'User1', { bg = '#dddde1', fg = '#9f6809', underline = true, bold = true })
--         api.nvim_set_hl(0, 'User2', { bg = '#dddde1', fg = '#000000', underline = true, bold = true })
--         api.nvim_set_hl(0, 'User3', { bg = '#dddde1', fg = '#000000', underline = true, })
--         api.nvim_set_hl(0, 'User4', { bg = '#dddde1', fg = '#4e093f', underline = true, })
--         api.nvim_set_hl(0, 'User5', { bg = '#dddde1', fg = '#031968', underline = true, })
--         api.nvim_set_hl(0, 'User6', { bg = '#dddde1', fg = '#083244', underline = true, })
--     end,
-- })

-- Winbar
vim.opt.winbar = '%f'

-- Colorscheme
if not pcall(function()
	require'moonwalk'.setup({
		transparent = true
	})
	vim.o.background = 'light'
	vim.cmd.colorscheme'moonwalk'
end) then
	vim.api.nvim_err_writeln'missing colorscheme'
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



-- Key Mapping -----------------------------------------------------------------

-- Set space as leader key
vim.g.mapleader = ' '

-- Go to line header and end
keymap.set('n', 'gh', '^')
keymap.set('n', 'gl', 'g_')

-- Treat long lines as break lines
keymap.set('n', 'j', [[<Cmd>execute 'normal!' (v:count > 1 ? "m'" . v:count : 'g') . 'j'<CR>]])
keymap.set('n', 'k', [[<Cmd>execute 'normal!' (v:count > 1 ? "m'" . v:count : 'g') . 'k'<CR>]])

-- Toggle folding
keymap.set('n', '<leader><space>', 'za')

-- Save
keymap.set('n', '<leader>fs', '<Cmd>up ++p<CR>')

-- Split
keymap.set('n', '<leader>h', '<Cmd>split<CR>')
keymap.set('n', '<leader>v', '<Cmd>vsplit<CR>')

-- Tabs
keymap.set('n', '<leader>t', '<Cmd>tabnew<CR>')

-- Close buffer
keymap.set('n', '<leader>q', '<Cmd>bp|bd #<CR>')

-- Clean search highlight
keymap.set('n', '<BS>', '<Cmd>noh<CR>')

-- Switch windows focus
keymap.set('n', '<C-j>', '<C-w>j')
keymap.set('n', '<C-k>', '<C-w>k')
keymap.set('n', '<C-l>', '<C-w>l')
keymap.set('n', '<C-h>', '<C-w>h')
keymap.set('n', '<C-q>', '<C-w>q')
keymap.set('t', '<esc>', [[<C-\><C-n>]])

-- Shifting
keymap.set('v', '<', '<gv')
keymap.set('v', '>', '>gv')

-- Move visual block
keymap.set('v', 'J', "<Cmd>m '>+1<CR>gv=gv")
keymap.set('v', 'K', "<Cmd>m '<-2<CR>gv=gv")

-- Command line cursor move
keymap.set('c', '<C-h>', '<Left>')
keymap.set('c', '<C-h>', '<Right>')
keymap.set('c', '<C-k>', '<Up>')
keymap.set('c', '<C-j>', '<Down>')
keymap.set('c', '<C-a>', '<Home>')
keymap.set('c', '<C-e>', '<End>')

-- Swap ;/:
keymap.set({'n', 'v'}, ';', ':')
keymap.set({'n', 'v'}, ':', ';')

-- Edit without clobbering register
keymap.set('n', 's', '"_c')
keymap.set('n', 'ss', '"_cc')
keymap.set('n', 'S', '"_C')

-- Use <Tab> and <S-Tab> to navigate through popup menu
keymap.set('i', '<Tab>', function()
	return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true })
keymap.set('i', '<S-Tab>', function()
	return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
end, { expr = true })

-- Visual mode pressing * or # searches for the current selection
local function visual_selection(direction)
	local old_a = vim.fn.getreg('a')
	vim.cmd('normal! "ay')
	local selected_text = vim.fn.getreg('a')
	vim.fn.setreg('a', old_a)

	-- Escape backslashes in the selected text for literal searching
	-- In '\V' (very nomagic) mode, only '\' is special and needs escaping
	local escaped_text = selected_text:gsub('\\', '\\\\')

	-- Create a search pattern using '\V' for literal matching
	local pattern = '\\V' .. escaped_text

	-- Set the search register '/' to the pattern
	vim.fn.setreg('/', pattern)

	-- Attempt to search, but don't let it error out
	local ok = pcall(vim.cmd, 'normal! ' .. (direction == '*' and 'n' or 'N'))
	if not ok then
		vim.notify("No match found", vim.log.levels.ERROR)
	end
end
keymap.set('v', '*', function() visual_selection('*') end)
keymap.set('v', '#', function() visual_selection('#') end)


-- Autocmd ---------------------------------------------------------------------

-- Automatic create directory when it doesn't exist
api.nvim_create_autocmd('BufNewFile', {
	group = api.nvim_create_augroup('Mkdir', {}),
	callback = function(tbl)
		local file = tbl.file
		local dir = vim.fn.fnamemodify(file, ':p:h')
		if vim.fn.isdirectory(dir) == 0 then
			vim.fn.mkdir(dir, 'p')
		end
	end
})

-- Open help file in new tab
api.nvim_create_autocmd('BufWinEnter', {
	group = api.nvim_create_augroup('HelpInTabs', {}),
	pattern = '*.txt',
	callback = function (tbl)
		if vim.o.buftype == 'help' then
			-- convert help window to tab
			vim.cmd 'execute "normal! \\<C-W>T"'
		end
	end
})

-- Terminal options
api.nvim_create_autocmd('TermOpen', {
	group = api.nvim_create_augroup('Terminal', {}),
	callback = function()
		vim.opt_local.number = false
		vim.opt_local.relativenumber = false
		vim.opt_local.signcolumn = 'no'
		vim.opt_local.winbar = ''
		vim.cmd[[startinsert]]
	end
	-- command = 'setlocal nonumber norelativenumber statusline=#%n|startinsert'
})

-- Load plugin configs
api.nvim_create_autocmd('VimEnter', {
	group = api.nvim_create_augroup('Plugins', {}),
	callback = function()
		if api.nvim_get_option('loadplugins') then
			require 'plugins'
		end
	end,
	once = true
})
