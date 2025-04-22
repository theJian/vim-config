require('lint').linters_by_ft = {
	lua = { 'luacheck' },
	python = { 'ruff' },
	javascript = { 'quick-lint-js' },
	typescript = { 'quick-lint-js' },
}

vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave' }, {
	callback = function()
		require('lint').try_lint()
	end,
})
