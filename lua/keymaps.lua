local keymap = vim.keymap

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
-- keymap.set('n', '<leader>fs', '<Cmd>up ++p<CR>')

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
keymap.set({ 'n', 'v' }, ';', ':')
keymap.set({ 'n', 'v' }, ':', ';')

-- Edit without clobbering register
keymap.set('n', 's', '"_c')
keymap.set('n', 'ss', '"_cc')
keymap.set('n', 'S', '"_C')

-- Use <Tab> and <S-Tab> to navigate through popup menu
keymap.set('i', '<Tab>', function()
	return vim.fn.pumvisible() == 1 and '<C-n>' or '<Tab>'
end, { expr = true })
keymap.set('i', '<S-Tab>', function()
	return vim.fn.pumvisible() == 1 and '<C-p>' or '<S-Tab>'
end, { expr = true })

-- Visual mode pressing * or # searches for the current selection
local function visual_selection(direction)
	local old_a = vim.fn.getreg 'a'
	vim.cmd 'normal! "ay'
	local selected_text = vim.fn.getreg 'a'
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
		vim.notify('No match found', vim.log.levels.ERROR)
	end
end
keymap.set('v', '*', function()
	visual_selection '*'
end)
keymap.set('v', '#', function()
	visual_selection '#'
end)
