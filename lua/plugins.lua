local api = vim.api
local fn = vim.fn

require'packman'

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
local cmp = require'cmp'

cmp.setup({
	snippet = {
		expand = function(args)
			require('luasnip').lsp_expand(args.body)
		end,
	},
	mapping = {
		["<C-p>"] = cmp.mapping.select_prev_item(),
		["<C-n>"] = cmp.mapping.select_next_item(),
	-- 	["<Tab>"] = cmp.mapping(function(fallback)
	-- 		if cmp.visible() then
	-- 			cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
	-- 		else
	-- 			fallback()
	-- 		end
	-- 	end, {"i","s","c",}),
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
vim.lsp.set_log_level 'trace'
if vim.fn.has 'nvim-0.5.1' == 1 then
	require('vim.lsp.log').set_format_func(vim.inspect)
end
local lsp = require'lspconfig'
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

-- TODO: remove to LspAttach group
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

api.nvim_create_autocmd('LspAttach', {
	callback = function (ev)

		local opts = { buffer = ev.buf }
		vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
		vim.keymap.set('n', '<C-d>', vim.diagnostic.open_float, opts)

		api.nvim_create_autocmd({'CursorHold', 'CursorHoldI'}, {
			buffer = ev.buf,
			callback = vim.lsp.buf.document_highlight,
		})

		api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
			buffer = ev.buf,
			callback = vim.lsp.buf.clear_references,
		})

		api.nvim_create_autocmd({'BufEnter', 'CursorHold', 'InsertLeave'}, {
			buffer = ev.buf,
			callback = vim.lsp.codelens.refresh,
		})

	end
})


-- diagnostics
vim.diagnostic.config({
	virtual_text = false,
	sign = true,
})
fn.sign_define({
	{ name = 'DiagnosticSignError', text = '🧨' },
	{ name = 'DiagnosticSignWarn', text = '🤨' },
	{ name = 'DiagnosticSignInfo', text = '📘' },
	{ name = 'DiagnosticSignHint', text = '💡' },
})


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
fit_find('<leader>ff', fit_files)
fit_find('<leader>fe', fit_current_dir_files)
fit_buffers('<leader>fb')

require'nvim-treesitter.configs'.setup {
	ensure_installed = {"c", "lua", "vim", "vimdoc", "query", "javascript", "typescript", "json"},
	highlight = {
		enable = true,
	},
	indent = {
		enable = true
	},
}

require'lualine'.setup {
	options = {
		icons_enabled = false,
		theme = 'auto',
		component_separators = '❘',
		section_separators = '',
		disabled_filetypes = {
			statusline = {},
			winbar = {},
		},
		ignore_focus = {},
		always_divide_middle = true,
		globalstatus = true,
		refresh = {
			statusline = 1000,
			tabline = 1000,
			winbar = 1000,
		},
		tabline_always_visible = false,
	},
	sections = {
		lualine_a = {'mode'},
		lualine_b = {'branch', 'diff'},
		lualine_c = {},
		lualine_x = {},
		lualine_y = {'location'},
		lualine_z = {
			{ 'datetime', style = '⏰ %H:%M' }
		}
	},
	tabline = {
		lualine_a = {'tabs'},
		lualine_b = {},
		lualine_c = {},
		lualine_x = {},
		lualine_y = {},
		lualine_z = {}
	},
	winbar = {
		lualine_a = {
			{
				'filename',
				file_status = true,      -- Displays file status (readonly status, modified status)
				newfile_status = false,  -- Display new file status (new file means no write after created)
				path = 1,
				-- 0: Just the filename
				-- 1: Relative path
				-- 2: Absolute path
				-- 3: Absolute path, with tilde as the home directory
				-- 4: Filename and parent dir, with tilde as the home directory

				symbols = {
					modified = '🚧',      -- Text to show when the file is modified.
					readonly = '🔒',      -- Text to show when the file is non-modifiable or readonly.
					unnamed = 'ɴᴏ ɴᴀᴍᴇ',       -- Text to show for unnamed buffers.
					newfile = 'ɴɛɯ',     -- Text to show for newly created file before first write
				}
			}
		},
		lualine_b = {},
		lualine_c = {},
		lualine_x = {{
			'diagnostics',
			symbols = {error = '🧨', warn = '🤨', info = '📘', hint = '💡'},
		}, 'filetype'},
		lualine_y = {},
		lualine_z = {},
	},
	inactive_winbar = {
		lualine_a = {
			{
				'filename',
				file_status = true,      -- Displays file status (readonly status, modified status)
				newfile_status = false,  -- Display new file status (new file means no write after created)
				path = 1,
				-- 0: Just the filename
				-- 1: Relative path
				-- 2: Absolute path
				-- 3: Absolute path, with tilde as the home directory
				-- 4: Filename and parent dir, with tilde as the home directory

				symbols = {
					modified = '🚧',      -- Text to show when the file is modified.
					readonly = '🔒',      -- Text to show when the file is non-modifiable or readonly.
					unnamed = 'ɴᴏ ɴᴀᴍᴇ',       -- Text to show for unnamed buffers.
					newfile = 'ɴɛɯ',     -- Text to show for newly created file before first write
				}
			}
		},
		lualine_b = {},
		lualine_c = {},
		lualine_x = {{
			'diagnostics',
			symbols = {error = '🧨', warn = '🤨', info = '📘', hint = '💡'},
		}, 'filetype'},
		lualine_y = {},
		lualine_z = {},
	},
	extensions = {}
}

require'colorizer'.setup()
