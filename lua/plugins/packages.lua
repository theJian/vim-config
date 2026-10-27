-- Register build hooks before adding the plugin packages.
vim.api.nvim_create_autocmd('PackChanged', {
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		if kind ~= 'install' and kind ~= 'update' then
			return
		end
		if name == 'blink.pairs' or name == 'vim-markdown-composer' then
			local result = vim.system({ 'cargo', 'build', '--release', '--locked' }, {
				cwd = ev.data.path,
				text = true,
			}):wait()
			if result.code ~= 0 then
				error(('Failed to build %s: %s'):format(name, result.stderr))
			end
		end
	end,
})

vim.pack.add {
	'https://github.com/saghen/blink.pairs',
	'https://github.com/mhartington/formatter.nvim',
	'https://github.com/lewis6991/gitsigns.nvim.git',
	'https://github.com/MagicDuck/grug-far.nvim.git',
	'https://github.com/lukas-reineke/indent-blankline.nvim',
	'https://github.com/smjonas/live-command.nvim',
	'https://github.com/nvim-lualine/lualine.nvim',
	'https://github.com/L3MON4D3/LuaSnip',
	'https://github.com/williamboman/mason-lspconfig.nvim',
	'https://github.com/williamboman/mason.nvim',
	'https://github.com/norcalli/nvim-colorizer.lua',
	'https://github.com/mfussenegger/nvim-dap',
	'https://github.com/leoluz/nvim-dap-go',
	'https://github.com/rcarriga/nvim-dap-ui',
	'https://github.com/theHamsta/nvim-dap-virtual-text',
	'https://github.com/mfussenegger/nvim-lint',
	'https://github.com/neovim/nvim-lspconfig.git',
	'https://github.com/bfredl/nvim-luadev',
	'https://github.com/nvim-neotest/nvim-nio',
	'https://github.com/julienvincent/nvim-paredit.git',
	'https://github.com/gpanders/nvim-parinfer.git',
	'https://github.com/kylechui/nvim-surround.git',
	'https://github.com/nvim-treesitter/nvim-treesitter',
	'https://github.com/nvim-treesitter/nvim-treesitter-context',
	'https://github.com/stevearc/oil.nvim.git',
	'https://github.com/jbyuki/one-small-step-for-vimkind',
	'https://github.com/tpope/vim-fugitive.git',
	'https://github.com/euclio/vim-markdown-composer',
}
