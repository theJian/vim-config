-- Configure EmmyLua for this Neovim configuration project.
-- Loaded by 'exrc' after this file is trusted with :trust.
vim.lsp.config('emmylua_ls', {
	---@type lspconfig.settings.emmylua_ls
	settings = {
		emmylua = {
			runtime = {
				version = 'LuaJIT',
			},
			diagnostics = {
				globals = { 'vim' },
			},
			workspace = {
				-- Keep symlinked runtime roots consistent with workspace file URIs.
				library = vim.tbl_map(function(path)
					return vim.uv.fs_realpath(path) or path
				end, vim.api.nvim_get_runtime_file('', true)),
			},
		},
	},
})
