local api = vim.api
local fn = vim.fn

require 'packman'

-- Netrw
vim.g.netrw_liststyle = 3
vim.g.netrw_altfile = 1
vim.g.netrw_banner = 0
vim.g.netrw_special_syntax = 1


-- delimitMate
vim.g.delimitMate_expand_cr = 1
vim.g.delimitMate_expand_space = 1
vim.g.delimitMate_jump_expansion = 1
vim.g.delimitMate_excluded_regions = "Comment"
vim.g.delimitMate_excluded_ft = "md,lisp"


-- -- ultisnips
-- vim.g.UltiSnipsSnippetDirectories = { vim.fn.fnamemodify(vim.env.MYVIMRC, ':h') .. '/UltiSnips' }
-- vim.g.UltiSnipsExpandTrigger = '<c-j>'
-- vim.g.UltiSnipsListSnippets = '<c-l>'
-- vim.g.UltiSnipsJumpForwardTrigger = '<c-j>'
-- vim.g.UltiSnipsJumpBackwardTrigger = '<c-k>'
-- vim.g.UltiSnipsEditSplit = 'vertical'


-- yankstack
-- rainbow pairs


-- markdown preview
vim.g.markdown_composer_autostart = 0


-- slimv
vim.g.slimv_impl = 'sbcl'
vim.g.slimv_unmap_cr = 1
vim.g.paredit_electric_return = 0
vim.g.slimv_keybindings = 2


-- far.vim
-- let g:far#source='rg'


-- vim-sexp
vim.g.sexp_enable_insert_mode_mappings = 0

-- completion
local cmp = require 'cmp'

cmp.setup({
	snippet = {
		expand = function(args)
			require('luasnip').lsp_expand(args.body)
		end,
	},
	sources = cmp.config.sources({
		{ name = 'nvim_lsp' },
		{ name = 'luasnip' },
		{ name = 'buffer' }
	})
})

cmp.setup.cmdline({ '/', '?' }, {
	mapping = cmp.mapping.preset.cmdline(),
	sources = {
		{ name = 'buffer' }
	}
})

cmp.setup.cmdline(':', {
	mapping = cmp.mapping.preset.cmdline(),
	sources = cmp.config.sources({
		{ name = 'path' }
	}, {
		{ name = 'cmdline' }
	})
})

-- LSP
local lsp = require 'lspconfig'
local capabilities = require('cmp_nvim_lsp').default_capabilities()

local function lsp_setup(target, options)
	options = options or {}
	options.capabilities = capabilities
	lsp[target].setup(options)
end
lsp_setup('rust_analyzer')
lsp_setup('pyright', {})
lsp_setup('bashls', {})
lsp_setup('tsserver', {})
lsp_setup('jsonls', {})
lsp_setup('cssls', {})
lsp_setup('gopls', {
	cmd = { fn.trim(fn.system('go env GOPATH')) .. "/bin/gopls" };
})

local function lsp_keymap(lhs, methodName)
	vim.api.nvim_set_keymap(
		'n',
		lhs,
		string.format(
			'<cmd>lua '..
			'if vim.tbl_isempty(vim.lsp.buf_get_clients()) then '..
				'vim.api.nvim_feedkeys("%s", "n", true) '..
			'else '..
				'vim.lsp.buf.%s() '..
			'end<CR>',
			lhs, methodName
		),
		{ unique = true, silent = true }
	)
end

lsp_keymap('gd',    'declaration')
lsp_keymap('<c-]>', 'definition')
lsp_keymap('K',     'hover')
lsp_keymap('gI',    'implementation')
lsp_keymap('gs',    'signature_help')
lsp_keymap('gy',    'type_definition')
lsp_keymap('gr',    'references')
lsp_keymap('g0',    'document_symbol')

local function fit_find(lhs, find_command, accept_command)
	local find_command_with_query = find_command .. '|fzy --show-matches=<query>|head -n 30'
	vim.api.nvim_set_keymap(
		'n',
		lhs,
		string.format(
			'<cmd>lua require("fit").find(%q, %q)<CR>',
			find_command_with_query, accept_command or 'e'
		),
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
local fit_repos = 'find ~ -maxdepth 2 -type d -execdir test -d {}/.git \\; -print -prune'
fit_find('<leader>ff', fit_files)
fit_find('<leader>fe', fit_current_dir_files)
fit_find('<leader>d', fit_repos, 'tcd')
fit_buffers('<leader>fb')

vim.g.pura_color_test = 1

if jit.os == 'linux' then
	require'nvim-treesitter.configs'.setup {
		highlight = {
			enable = true,
		},
	}
end
