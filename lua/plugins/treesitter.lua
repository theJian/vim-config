require'nvim-treesitter.configs'.setup {
	ensure_installed = {
		"c",
		"lua", 
		"vim", 
		"vimdoc", 
		"query", 
		"javascript", 
		"typescript", 
		"json", 
		"tsx", 
		"go", 
		"gomod",
		"html",
		"erlang",
		"elixir",
		"solidity",
		"yaml",
		"css",
		"bash",
		"astro",
		"rust",
		"python",
	},
	highlight = {
		enable = true,
	},
	indent = {
		enable = true
	},
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "vin",
			node_incremental = "]",
			node_decremental = "[",
			scope_incremental = "grc",
      },
	},
}
