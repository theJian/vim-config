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

-- Open help in a centered floating window
api.nvim_create_autocmd('BufWinEnter', {
	group = api.nvim_create_augroup('HelpInFloat', {}),
	callback = function(args)
		if vim.bo[args.buf].buftype ~= 'help' then
			return
		end

		local width = math.max(1, math.floor(vim.o.columns * 0.8))
		local height = math.max(1, math.floor((vim.o.lines - vim.o.cmdheight - 2) * 0.8))
		api.nvim_win_set_config(0, {
			relative = 'editor',
			width = width,
			height = height,
			row = math.floor((vim.o.lines - vim.o.cmdheight - height - 2) / 2),
			col = math.floor((vim.o.columns - width - 2) / 2),
			border = 'rounded',
		})
		vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = args.buf, desc = 'Close help' })
	end,
})

-- Terminal options
api.nvim_create_autocmd('TermOpen', {
	group = api.nvim_create_augroup('Terminal', {}),
	callback = function()
		vim.bo.filetype = 'terminal'
		vim.opt_local.winbar = ''
		vim.opt_local.spell = false
		vim.cmd [[startinsert]]
	end,
})

-- Auto-enter terminal mode when switching to a terminal buffer
api.nvim_create_autocmd('BufEnter', {
	group = 'Terminal',
	pattern = 'term://*',
	command = 'startinsert',
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
local timer = vim.uv.new_timer()
local DEBOUNCE_DELAY = 500 -- ms

local function has_syntax_errors(buf)
	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then
		return false -- no parser available, assume valid
	end
	local tree = parser:parse()[1]
	return tree:root():has_error()
end

local function save(ctx)
	local buf = ctx.buf

	if not vim.api.nvim_buf_get_name(buf) or vim.api.nvim_buf_get_name(buf) == '' then
		return
	end
	if not vim.bo[buf].modified then
		return
	end
	if vim.bo[buf].readonly then
		return
	end
	if vim.bo[buf].buftype ~= '' then
		return
	end

	if not has_syntax_errors(buf) then
		vim.api.nvim_buf_call(buf, function()
			vim.cmd 'silent! update'
		end)
	end
end

api.nvim_create_autocmd({ 'InsertLeave' }, {
	pattern = '*',
	nested = true, -- trigger code formatting
	callback = save,
})
api.nvim_create_autocmd({ 'TextChanged' }, {
	pattern = '*',
	callback = save,
})

-- restore cursor to file position in previous editing session
api.nvim_create_autocmd('BufReadPost', {
	callback = function(args)
		-- Skip non-file buffers
		if vim.bo[args.buf].buftype ~= '' then
			return
		end

		local mark = api.nvim_buf_get_mark(args.buf, '"')
		local line_count = api.nvim_buf_line_count(args.buf)
		if mark[1] > 0 and mark[1] <= line_count then
			api.nvim_win_set_cursor(0, mark)
			-- defer centering slightly so it's applied after render
			vim.schedule(function()
				if vim.api.nvim_get_mode().mode == 'n' then
					vim.cmd 'normal! zz'
				end
			end)
		end
	end,
})
