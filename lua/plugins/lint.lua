require('lint').linters_by_ft = {
	lua = { 'luacheck' },
	python = { 'ruff' },
	javascript = { 'eslint' },
	typescript = { 'eslint' },
}

vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost', 'InsertLeave' }, {
	callback = function()
		require('lint').try_lint()
	end,
})
