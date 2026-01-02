return {
	settings = {
		['rust-analyzer'] = {
			diagnostics = {
				enable = false,
			},
			checkOnSave = {
				enable = false,
			},
			inlayHints = {
				chainingHints = { enable = true },
				closingBraceHints = { enable = true, minLines = 25 },
				parameterHints = { enable = true },
				typeHints = { enable = true },
			},
			imports = {
				granularity = {
					group = 'module',
				},
				prefix = 'self',
			},
			cargo = {
				buildScripts = {
					enable = true,
				},
			},
			procMacro = {
				enable = true,
			},
		},
	},
}
