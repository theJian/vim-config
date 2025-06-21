local api = vim.api

-- Automatic create directory when it doesn't exist
api.nvim_create_autocmd('BufNewFile', {
	group = api.nvim_create_augroup('Mkdir', {}),
	callback = function(tbl)
		local file = tbl.file
		local dir = vim.fn.fnamemodify(file, ':p:h')
		if vim.fn.isdirectory(dir) == 0 then
			vim.fn.mkdir(dir, 'p')
		end
	end,
})

-- Open help file in new tab
api.nvim_create_autocmd('BufWinEnter', {
	group = api.nvim_create_augroup('HelpInTabs', {}),
	pattern = '*.txt',
	callback = function()
		if vim.o.buftype == 'help' then
			-- convert help window to tab
			vim.cmd 'execute "normal! \\<C-W>T"'
		end
	end,
})

-- Terminal options
api.nvim_create_autocmd('TermOpen', {
	group = api.nvim_create_augroup('Terminal', {}),
	callback = function()
		vim.opt_local.winbar = ''
		vim.cmd [[startinsert]]
	end,
})

-- Load plugin configs
api.nvim_create_autocmd('VimEnter', {
	group = api.nvim_create_augroup('Plugins', {}),
	callback = function()
		if api.nvim_get_option_value('loadplugins', {}) then
			require 'plugins'
		end
	end,
	once = true,
})

-- Reload file if it has been changed outside of Vim
api.nvim_create_autocmd({ 'FocusGained', 'BufEnter' }, {
	group = api.nvim_create_augroup('ReloadContent', {}),
	callback = function()
		if vim.fn.getfsize(vim.fn.expand '%:p') > 0 then
			vim.cmd 'checktime'
		end
	end,
})

-- Resize window when resizing the terminal
api.nvim_create_autocmd('VimResized', {
	group = api.nvim_create_augroup('ResizeWindow', {}),
	callback = function()
		vim.cmd 'tabdo wincmd ='
	end,
})

-- Autosave
api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged' }, {
	pattern = '*',
	callback = function()
		if vim.bo.modified then
			vim.cmd 'silent! update'
		end
	end,
})
