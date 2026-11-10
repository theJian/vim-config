-- Configure automatic pairing and pair highlights with Blink. Its managed
-- builder places the native library for loading; add the helper first because
-- native lock restoration can install pairs early.
vim.pack.add { 'https://github.com/saghen/blink.lib' }

vim.api.nvim_create_autocmd('PackChanged', {
	group = vim.api.nvim_create_augroup('BlinkPairsBuild', { clear = true }),
	callback = function(ev)
		local data = ev.data
		if data.spec.name == 'blink.pairs' and (data.kind == 'install' or data.kind == 'update') then
			if not data.active then
				vim.cmd.packadd 'blink.pairs'
			end
			require('blink.pairs').build():wait()
		end
	end,
})

vim.pack.add { 'https://github.com/saghen/blink.pairs' }
local pairs = require 'blink.pairs'
-- Also cover earlier lock restoration and existing installs missing a library.
pairs.build():wait()
pairs.setup {}
