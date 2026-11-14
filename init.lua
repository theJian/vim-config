vim.loader.enable()

-- Keep bundled help available before other configuration modules load.
do
	local doc = vim.fn.stdpath('config') .. '/doc'
	local files = {}
	if vim.fn.isdirectory(doc) == 1 then
		for _, name in ipairs(vim.fn.readdir(doc)) do
			local file = doc .. '/' .. name
			if name:sub(-4) == '.txt' and vim.fn.filereadable(file) == 1 then
				files[#files + 1] = file
			end
		end
	end
	local tags_time = vim.fn.getftime(doc .. '/tags')
	local stale = tags_time < 0 or vim.fn.getftime(doc) >= tags_time
	for _, file in ipairs(files) do
		if vim.fn.getftime(file) >= tags_time then
			stale = true
			break
		end
	end
	if #files > 0 and stale then
		vim.cmd.helptags { doc, magic = { file = false } }
	end
end

require 'prelude'
require 'options'
require 'ui'
require 'keymaps'
require('workspaces').setup()
require('projects').setup()
require 'autocmds'

require('which_key').setup {
	groups = {
		['<leader>p'] = 'Projects',
		['<leader><Tab>'] = 'Workspaces',
		['<leader>w'] = 'Windows',
		['<leader>b'] = 'Buffers',
	},
}
