require('blink.cmp').setup {
	completion = {
		documentation = { auto_show = true, auto_show_delay_ms = 500 },
		list = {
			selection = { preselect = false, auto_insert = true },
		},
		trigger = {
			-- rust-analyzer offers trait members on an otherwise empty impl line.
			show_on_blocked_trigger_characters = {},
		},
	},
	sources = {
		providers = {
			lsp = {
				override = {
					get_trigger_characters = function(self)
						local trigger_characters = self:get_trigger_characters()
						vim.list_extend(trigger_characters, { '\n', '\t', ' ' })
						return trigger_characters
					end,
				},
			},
		},
	},
	signature = { enabled = true },
	-- Keymap configuration
	keymap = {
		preset = 'default',

		['<CR>'] = { 'accept', 'fallback' },

		['<Right>'] = { 'accept', 'fallback' },

		['<Tab>'] = {
			'select_next', -- Select next item in list if menu is open
			'snippet_forward', -- Jump to next snippet placeholder if snippet is active
			'fallback', -- Insert a tab character (or indent)
		},

		['<S-Tab>'] = {
			'select_prev',
			'snippet_backward',
			'fallback',
		},
	},
}
