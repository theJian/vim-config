-- Provides the Format, FormatWrite, FormatLock, and FormatWriteLock commands
require('formatter').setup {
	-- Enable or disable logging
	logging = false,
	-- Set the log level
	log_level = vim.log.levels.WARN,
	-- All formatter configurations are opt-in
	filetype = {
		-- Formatter configurations for filetype "lua" go here
		-- and will be executed in order
		lua = require('formatter.filetypes.lua').stylua,
		javascript = require('formatter.filetypes.javascript').prettier,
		javascriptreact = require('formatter.filetypes.javascriptreact').prettier,
		typescript = require('formatter.filetypes.typescript').prettier,
		typescriptreact = require('formatter.filetypes.typescriptreact').prettier,
		css = require('formatter.filetypes.css').prettier,
		html = require('formatter.filetypes.html').prettier,
		json = require('formatter.filetypes.json').prettier,
		elixir = require('formatter.filetypes.elixir').mixformat,
		go = require('formatter.filetypes.go').gofmt,
		python = require('formatter.filetypes.python').ruff,
		rust = require('formatter.filetypes.rust').rustfmt,

		-- Use the special "*" filetype for defining formatter configurations on
		-- any filetype
		['*'] = {
			-- "formatter.filetypes.any" defines default configurations for any
			-- filetype
			require('formatter.filetypes.any').remove_trailing_whitespace,
			-- Remove trailing whitespace without 'sed'
			-- require("formatter.filetypes.any").substitute_trailing_whitespace,
		},
	},
}

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
augroup('__formatter__', { clear = true })
autocmd('BufWritePost', {
	group = '__formatter__',
	command = ':FormatWrite',
})
