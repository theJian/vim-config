vim.loader.enable()

require 'options'
require 'packages'
vim.pack.add {
	'git@github.com:theJian/nvim-moonwalk.git',
}
require 'ui'
require 'keymaps'
require('workspaces').setup()
require('projects').setup()
require 'autocmds'
