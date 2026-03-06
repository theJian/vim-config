require('lint').linters_by_ft = {
	lua = { 'luacheck' },
	python = { 'ruff' },
	javascript = { 'quick-lint-js', 'eslint_d' },
	typescript = { 'quick-lint-js', 'eslint_d' },
	javascriptreact = { 'quick-lint-js', 'eslint_d' },
	typescriptreact = { 'quick-lint-js', 'eslint_d' },
}

vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave' }, {
	callback = function()
		require('lint').try_lint()
	end,
})
