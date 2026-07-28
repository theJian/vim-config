vim.api.nvim_create_autocmd('VimEnter', {
	once = true,
	callback = function()
		vim.schedule(function()
			local ok, err = pcall(function()
				assert(vim.deep_equal(vim.opt.completeopt:get(), { 'fuzzy', 'menuone', 'noselect', 'popup' }))
				assert(package.loaded['plugins.completion'])
				assert(not package.loaded['blink.cmp'])
				assert(package.loaded['blink.pairs'])
				assert(vim.fn.maparg('<Tab>', 'i', false, true).desc == 'Select next completion or snippet tabstop')
			end)

			if not ok then
				vim.api.nvim_err_writeln('FAIL: startup integration: ' .. err)
				vim.cmd.cquit()
				return
			end

			vim.api.nvim_out_write 'PASS: startup integration\n'
			vim.cmd.qa()
		end)
	end,
})
