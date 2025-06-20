local function fit_find(lhs, find_command, accept_command)
	local find_command_with_query = find_command .. '|fzy --show-matches=<query>|head -n 30'
	vim.api.nvim_set_keymap(
		'n',
		lhs,
		string.format('<cmd>lua require("fit").find(%q, %q)<CR>', find_command_with_query, accept_command or 'e'),
		{ unique = true, silent = true }
	)
end

local function fit_buffers(lhs)
	vim.api.nvim_set_keymap(
		'n',
		lhs,
		'<cmd>lua require("fit").buffers("fzy --show-matches=<query>")<CR>',
		{ unique = true, silent = true }
	)
end

local fit_files = 'rg --color never --files <cwd>'
local fit_current_dir_files = 'rg --color never --files <dir>'
fit_find('<leader>f', fit_files)
fit_find('<leader>e', fit_current_dir_files)
fit_buffers '<leader>b'
