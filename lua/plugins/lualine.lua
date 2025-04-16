require'lualine'.setup {
	options = {
		icons_enabled = true,
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
		lualine_b = {
			{'branch', icon = ''},
			'diff'
		},
		lualine_c = {},
		lualine_x = {},
		lualine_y = {'location'},
		lualine_z = {
			{ 'datetime', style = '🕰 %H:%M' }
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
					modified = '',      -- Text to show when the file is modified.
					readonly = '',      -- Text to show when the file is non-modifiable or readonly.
					unnamed = '- NO NAME -',       -- Text to show for unnamed buffers.
					newfile = '- NEW -',     -- Text to show for newly created file before first write
				}
			}
		},
		lualine_b = {},
		lualine_c = {},
		lualine_x = {{
			'diagnostics',
			symbols = {error = '● ', warn = '● ', info = '○ ', hint = '⊙ '},
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
					modified = '',      -- Text to show when the file is modified.
					readonly = '',      -- Text to show when the file is non-modifiable or readonly.
					unnamed = '- NO NAME -',       -- Text to show for unnamed buffers.
					newfile = '- NEW -',     -- Text to show for newly created file before first write
				}
			}
		},
		lualine_b = {},
		lualine_c = {},
		lualine_x = {{
			'diagnostics',
			symbols = {error = '● ', warn = '● ', info = '○ ', hint = '⊙ '},
		}, 'filetype'},
		lualine_y = {},
		lualine_z = {},
	},
	extensions = {}
}
