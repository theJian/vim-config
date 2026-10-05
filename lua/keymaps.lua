local keymap = vim.keymap

-- Set space as leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Go to line header and end
keymap.set('n', 'gh', '^')
keymap.set('n', 'gl', 'g_')

-- Treat long lines as break lines
keymap.set('n', 'j', [[<Cmd>execute 'normal!' (v:count > 1 ? "m'" . v:count : 'g') . 'j'<CR>]])
keymap.set('n', 'k', [[<Cmd>execute 'normal!' (v:count > 1 ? "m'" . v:count : 'g') . 'k'<CR>]])

-- Save
-- keymap.set('n', '<leader>fs', '<Cmd>up ++p<CR>')

-- Split
keymap.set('n', '<leader>ws', '<Cmd>split<CR>')
keymap.set('n', '<leader>wv', '<Cmd>vsplit<CR>')

-- Tabs
keymap.set('n', '<leader>t', '<Cmd>tabnew<CR>')
for i = 1, 9 do
	keymap.set('n', '<M-' .. i .. '>', i .. 'gt')
	keymap.set('i', '<M-' .. i .. '>', '<Cmd>tabn ' .. i .. '<CR>')
	keymap.set('t', '<M-' .. i .. '>', '<Cmd>tabn ' .. i .. '<CR>')
end

-- Close buffer
keymap.set('n', '<leader>x', '<Cmd>bp|bd #<CR>')

-- Clean search highlight
keymap.set('n', '<CR>', function()
	return vim.v.hlsearch == 1 and '<Cmd>nohlsearch<CR>' or '<CR>'
end, { expr = true, desc = 'Clear active search highlights' })

-- Switch windows focus
keymap.set('n', '<leader>wj', '<C-w>j')
keymap.set('n', '<leader>wk', '<C-w>k')
keymap.set('n', '<leader>wl', '<C-w>l')
keymap.set('n', '<leader>wh', '<C-w>h')
keymap.set('n', '<C-q>', '<C-w>q')
keymap.set('t', '<esc>', [[<C-\><C-n>]])

-- Send raw ESC byte to the underlying TUI program (e.g. opencode modal close)
keymap.set('t', '<C-[>', function()
	vim.api.nvim_chan_send(vim.bo.channel, '\27')
end, { desc = 'Send ESC to TUI program' })

-- Switch windows from terminal mode (no need to press esc first)
keymap.set('t', '<leader>wh', [[<C-\><C-n><C-w>h]])
keymap.set('t', '<leader>wj', [[<C-\><C-n><C-w>j]])
keymap.set('t', '<leader>wk', [[<C-\><C-n><C-w>k]])
keymap.set('t', '<leader>wl', [[<C-\><C-n><C-w>l]])

-- Shifting
keymap.set('v', '<', '<gv')
keymap.set('v', '>', '>gv')

-- Move visual block
keymap.set('v', 'J', "<Cmd>m '>+1<CR>gv=gv")
keymap.set('v', 'K', "<Cmd>m '<-2<CR>gv=gv")

-- Command line cursor move
keymap.set('c', '<C-a>', '<Home>')
keymap.set('c', '<C-e>', '<End>')

-- Swap ;/:
keymap.set({ 'n', 'v' }, ';', ':')
keymap.set({ 'n', 'v' }, ':', ';')

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
