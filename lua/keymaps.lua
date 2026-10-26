local keymap = vim.keymap

-- Set space as leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Help buffer mappings
vim.api.nvim_create_autocmd('FileType', {
	group = vim.api.nvim_create_augroup('HelpKeymaps', { clear = true }),
	pattern = 'help',
	callback = function(args)
		keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = args.buf, desc = 'Close help', unique = true })
	end,
})

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

-- Workspaces
for key, item in pairs {
	['<Tab>'] = { 'list', 'Display workspaces' },
	['.'] = { 'switch', 'Switch workspace' },
	['`'] = { 'last', 'Switch to last workspace' },
	['n'] = { 'new', 'New workspace' },
	['N'] = { 'new-named', 'New named workspace' },
	['l'] = { 'load', 'Load workspace from file' },
	['s'] = { 'save', 'Save workspace to file' },
	['x'] = { 'clear', 'Kill session' },
	['d'] = { 'kill', 'Kill this workspace' },
	['D'] = { 'delete-saved', 'Delete saved workspace' },
	['r'] = { 'rename', 'Rename workspace' },
	['R'] = { 'restore', 'Restore last session' },
	[']'] = { 'next', 'Next workspace' },
	['['] = { 'previous', 'Previous workspace' },
} do
	keymap.set(
		'n',
		'<leader><Tab>' .. key,
		'<Plug>(acme-workspaces-' .. item[1] .. ')',
		{ desc = item[2], unique = true }
	)
end

-- Projects
for key, item in pairs {
	['.'] = { 'browse', 'Browse project' },
	['>'] = { 'browse-other', 'Browse other project' },
	['!'] = { 'shell', 'Run command in project root' },
	['&'] = { 'async', 'Async command in project root' },
	['a'] = { 'add', 'Add new project' },
	['b'] = { 'buffers', 'Switch to project buffer' },
	['c'] = { 'compile', 'Compile project' },
	['C'] = { 'repeat', 'Repeat last project command' },
	['d'] = { 'remove', 'Remove known project' },
	['D'] = { 'discover', 'Discover projects in folder' },
	['e'] = { 'edit-config', 'Edit project local configuration' },
	['f'] = { 'find', 'Find file in project' },
	['F'] = { 'find-other', 'Find file in other project' },
	['g'] = { 'configure', 'Configure project' },
	['i'] = { 'invalidate', 'Invalidate project cache' },
	['k'] = { 'kill', 'Kill project buffers' },
	['o'] = { 'sibling', 'Find sibling file' },
	['p'] = { 'switch', 'Switch project' },
	['r'] = { 'recent', 'Find recent project files' },
	['R'] = { 'run', 'Run project' },
	['s'] = { 'save', 'Save project files' },
	['T'] = { 'test', 'Test project' },
	['x'] = { 'scratch-toggle', 'Toggle project scratch buffer' },
	['X'] = { 'scratch', 'Switch to project scratch buffer' },
} do
	keymap.set('n', '<leader>p' .. key, '<Plug>(acme-projects-' .. item[1] .. ')', { desc = item[2], unique = true })
end

for i = 0, 9 do
	local plug = '<Plug>(acme-workspaces-' .. i .. ')'
	keymap.set('n', '<leader><Tab>' .. i, plug, { desc = 'Switch workspace ' .. i, unique = true })
	keymap.set({ 'n', 'i', 't' }, '<M-' .. i .. '>', plug, { desc = 'Switch workspace ' .. i, unique = true })
end
keymap.set('n', '<C-t>', '<Plug>(acme-workspaces-create)', { desc = 'New workspace', unique = true })
for _, key in ipairs { '<leader>,', '<leader>bb' } do
	keymap.set('n', key, '<Plug>(acme-workspaces-buffers)', { desc = 'Switch workspace buffer', unique = true })
end

-- Picker bindings exist only while better_select borrows the ui2 buffer.
local picker_mappings = {
	['<Down>'] = 'down',
	['<Up>'] = 'up',
	['<CR>'] = 'accept',
	['<Esc>'] = 'cancel',
	['<Tab>'] = 'mark',
	['<C-g>'] = 'toggle_live',
	['<C-l>'] = 'toggle_preview',
	['<C-q>'] = 'set_quickfix',
	['<C-s>'] = 'split',
	['<C-v>'] = 'vsplit',
	['<C-t>'] = 'tabnew',
}
require('better_select').setup {
	on_open = function(search)
		for key, action in pairs(picker_mappings) do
			local plug = '<Plug>(acme-better-select-' .. action:gsub('_', '-') .. ')'
			-- <unique> also checks global maps; picker-local keys intentionally shadow them.
			local global = vim.iter(vim.api.nvim_get_keymap('i')):find(function(map)
				return vim.keycode(map.lhs) == vim.keycode(key)
			end)
			if global then
				keymap.del('i', key)
			end
			local ok, err = pcall(keymap.set, 'i', key, plug, { buffer = search.buf, nowait = true, unique = true })
			if global then
				vim.fn.mapset('i', false, global)
			end
			if not ok then
				error(err)
			end
			search.view.restore[#search.view.restore + 1] = function()
				keymap.del('i', key, { buffer = search.buf })
			end
		end
	end,
}
