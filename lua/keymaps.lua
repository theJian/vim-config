local keymap = vim.keymap

-- Set space as leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Go to line header and end
keymap.set('n', 'gh', '^', { desc = 'Go to first nonblank character' })
keymap.set('n', 'gl', 'g_', { desc = 'Go to last nonblank character' })

-- Treat long lines as break lines
keymap.set(
	'n',
	'j',
	[[<Cmd>execute 'normal!' (v:count > 1 ? "m'" . v:count : 'g') . 'j'<CR>]],
	{ desc = 'Move down by display line, or by count with a jump mark' }
)
keymap.set(
	'n',
	'k',
	[[<Cmd>execute 'normal!' (v:count > 1 ? "m'" . v:count : 'g') . 'k'<CR>]],
	{ desc = 'Move up by display line, or by count with a jump mark' }
)

-- Save
-- keymap.set('n', '<leader>fs', '<Cmd>up ++p<CR>', { desc = 'Save file' })

-- Split
keymap.set('n', '<leader>ws', '<Cmd>split<CR>', { desc = 'Split window horizontally' })
keymap.set('n', '<leader>wv', '<Cmd>vsplit<CR>', { desc = 'Split window vertically' })

-- Tabs
keymap.set('n', '<leader>t', '<Cmd>tabnew<CR>', { desc = 'Open new tab' })
for i = 1, 9 do
	keymap.set('n', '<M-' .. i .. '>', i .. 'gt', { desc = 'Go to tab ' .. i })
	keymap.set('i', '<M-' .. i .. '>', '<Cmd>tabn ' .. i .. '<CR>', { desc = 'Go to tab ' .. i })
	keymap.set('t', '<M-' .. i .. '>', '<Cmd>tabn ' .. i .. '<CR>', { desc = 'Go to tab ' .. i })
end

-- Close buffer
keymap.set('n', '<leader>x', '<Cmd>bp|bd #<CR>', { desc = 'Switch to previous buffer and delete current buffer' })
keymap.set('n', '<leader>bd', '<Cmd>bdelete<CR>', { desc = 'Delete buffer' })

-- Clean search highlight
keymap.set('n', '<CR>', function()
	return vim.v.hlsearch == 1 and '<Cmd>nohlsearch<CR>' or '<CR>'
end, { expr = true, desc = 'Clear active search highlights' })

-- Switch windows focus
keymap.set('n', '<leader>wj', '<C-w>j', { desc = 'Focus window below' })
keymap.set('n', '<leader>wk', '<C-w>k', { desc = 'Focus window above' })
keymap.set('n', '<leader>wl', '<C-w>l', { desc = 'Focus window to the right' })
keymap.set('n', '<leader>wh', '<C-w>h', { desc = 'Focus window to the left' })
keymap.set('n', '<C-q>', '<C-w>q', { desc = 'Close window' })
keymap.set('t', '<esc>', [[<C-\><C-n>]], { desc = 'Exit terminal mode' })

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
keymap.set('v', '<', '<gv', { desc = 'Indent selection left and reselect' })
keymap.set('v', '>', '>gv', { desc = 'Indent selection right and reselect' })

-- Move visual block
keymap.set('v', 'J', "<Cmd>m '>+1<CR>gv=gv", { desc = 'Move selection down' })
keymap.set('v', 'K', "<Cmd>m '<-2<CR>gv=gv", { desc = 'Move selection up' })

-- Command line cursor move
keymap.set('c', '<C-a>', '<Home>', { desc = 'Go to start of command line' })
keymap.set('c', '<C-e>', '<End>', { desc = 'Go to end of command line' })

-- Swap ;/:
keymap.set({ 'n', 'v' }, ';', ':', { desc = 'Enter command line' })
keymap.set({ 'n', 'v' }, ':', ';', { desc = 'Repeat last character search' })
