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

				vim.keymap.set('i', '<F6>', function()
					vim.fn.complete(1, { 'apple', 'apricot' })
				end)
				vim.fn.feedkeys('i' .. vim.keycode '<F6><Tab><CR><Esc>', 'xt')
				vim.keymap.del('i', '<F6>')
				assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'apple' }))
				vim.bo.modified = false
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
