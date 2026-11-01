return {
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
}
