require('nvim-treesitter').install {
	"c",
	"lua",
	"vim",
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
	"git_config",
	"gitcommit",
	"gitignore",
	"git_rebase",
	"gitattributes",
	"make",
	"markdown",
	"toml",
}

vim.api.nvim_create_autocmd('FileType', {
	callback = function(args)
		local filetype = args.match
		local lang = vim.treesitter.language.get_lang(filetype)
		if lang and vim.treesitter.language.add(lang) then
			-- syntax highlighting, provided by Neovim
			vim.treesitter.start()
			-- folds, provided by Neovim
			vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
			vim.wo[0][0].foldmethod = 'expr'
			-- indentation, provided by nvim-treesitter
			vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end,
})

require("treesitter-context").setup{
	max_lines = 3,
	min_window_height = 15,
	multiline_threshold = 2,
}

	-- textobjects = {
	-- 	select = {
	-- 		enable = true,
	--
	-- 		-- Automatically jump forward to textobj, similar to targets.vim
	-- 		lookahead = true,
	--
	-- 		keymaps = {
	-- 			-- You can use the capture groups defined in textobjects.scm
	-- 			["aV"] = "@assignment.lhs",
	-- 			["av"] = "@assignment.rhs",
	-- 			["aa"] = "@parameter.outer",
	-- 			["ia"] = "@parameter.inner",
	-- 			["ai"] = "@conditional.outer",
	-- 			["ii"] = "@conditional.inner",
	-- 			["ao"] = "@loop.outer",
	-- 			["io"] = "@loop.inner",
	-- 			["af"] = "@function.outer",
	-- 			["if"] = "@function.inner",
	-- 			["ac"] = "@class.outer",
	-- 			-- You can optionally set descriptions to the mappings (used in the desc parameter of
	-- 			-- nvim_buf_set_keymap) which plugins like which-key display
	-- 			["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
	-- 			-- You can also use captures from other query groups like `locals.scm`
	-- 			["as"] = { query = "@local.scope", query_group = "locals", desc = "Select language scope" },
	-- 		},
	-- 		-- You can choose the select mode (default is charwise 'v')
	-- 		--
	-- 		-- Can also be a function which gets passed a table with the keys
	-- 		-- * query_string: eg '@function.inner'
	-- 		-- * method: eg 'v' or 'o'
	-- 		-- and should return the mode ('v', 'V', or '<c-v>') or a table
	-- 		-- mapping query_strings to modes.
	-- 		selection_modes = {
	-- 			["@parameter.inner"] = "v", -- charwise
	-- 			["@function.inner"] = "v", -- charwise
	-- 			["@class.inner"] = "v", -- charwise
	-- 			["@conditional.inner"] = "v", -- charwise
	-- 			["@loop.inner"] = "v", -- charwise
	-- 			["@parameter.outer"] = "V", -- linewise
	-- 			["@function.outer"] = "V", -- linewise
	-- 			["@class.outer"] = "V", -- linewise
	-- 			["@conditional.outer"] = "V", -- linewise
	-- 			["@loop.outer"] = "V", -- linewise
	-- 		},
	-- 		-- If you set this to `true` (default is `false`) then any textobject is
	-- 		-- extended to include preceding or succeeding whitespace. Succeeding
	-- 		-- whitespace has priority in order to act similarly to eg the built-in
	-- 		-- `ap`.
	-- 		--
	-- 		-- Can also be a function which gets passed a table with the keys
	-- 		-- * query_string: eg '@function.inner'
	-- 		-- * selection_mode: eg 'v'
	-- 		-- and should return true or false
	-- 		include_surrounding_whitespace = false,
	-- 	},
	-- 	swap = {
	-- 		enable = true,
	-- 		swap_next = {
	-- 			["<leader>a"] = "@parameter.inner",
	-- 		},
	-- 		swap_previous = {
	-- 			["<leader>A"] = "@parameter.inner",
	-- 		},
	-- 	},
	-- 	move = {
	-- 		enable = true,
	-- 		set_jumps = true, -- whether to set jumps in the jumplist
	-- 		goto_next_start = {
	-- 			["]f"] = "@function.outer",
	-- 			["]]"] = { query = "@class.outer", desc = "Next class start" },
	-- 			--
	-- 			-- You can use regex matching (i.e. lua pattern) and/or pass a list in a "query" key to group multiple queries.
	-- 			["]o"] = "@loop.*",
	-- 			-- ["]o"] = { query = { "@loop.inner", "@loop.outer" } }
	-- 			--
	-- 			-- You can pass a query group to use query from `queries/<lang>/<query_group>.scm file in your runtime path.
	-- 			-- Below example nvim-treesitter's `locals.scm` and `folds.scm`. They also provide highlights.scm and indent.scm.
	-- 			["]s"] = { query = "@local.scope", query_group = "locals", desc = "Next scope" },
	-- 			["]z"] = { query = "@fold", query_group = "folds", desc = "Next fold" },
	-- 		},
	-- 		goto_next_end = {
	-- 			["]F"] = "@function.outer",
	-- 			["]["] = "@class.outer",
	-- 		},
	-- 		goto_previous_start = {
	-- 			["[f"] = "@function.outer",
	-- 			["[["] = "@class.outer",
	-- 		},
	-- 		goto_previous_end = {
	-- 			["[F"] = "@function.outer",
	-- 			["[]"] = "@class.outer",
	-- 		},
	-- 		-- Below will go to either the start or the end, whichever is closer.
	-- 		-- Use if you want more granular movements
	-- 		-- Make it even more gradual by adding multiple queries and regex.
	-- 		goto_next = {
	-- 			["]i"] = "@conditional.outer",
	-- 		},
	-- 		goto_previous = {
	-- 			["[i"] = "@conditional.outer",
	-- 		},
	-- 	},
	-- 	lsp_interop = {
	-- 		enable = true,
	-- 		border = "none",
	-- 		floating_preview_opts = {},
	-- 		peek_definition_code = {
	-- 			["<leader>df"] = "@function.outer",
	-- 			["<leader>dF"] = "@class.outer",
	-- 		},
	-- 	},
	-- },
