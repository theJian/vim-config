require('blink.cmp').setup {
	completion = {
		documentation = { auto_show = true, auto_show_delay_ms = 500 },
		list = {
			selection = { preselect = false, auto_insert = true },
		},
	},
	signature = { enabled = true },
	-- Keymap configuration
	keymap = {
		preset = 'default',

		['<CR>'] = { 'accept', 'fallback' },

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
