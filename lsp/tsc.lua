-- TypeScript 7's native compiler doubles as the language server (`tsc --lsp`),
-- replacing the deprecated `tsgo` server from `@typescript/native-preview`.
--
-- Only preferences live here. The command (project-local `node_modules/.bin/tsc`
-- preferred over `$PATH`, must be major >= 7 to support `--lsp`), the filetypes
-- and the monorepo/deno root detection are inherited from nvim-lspconfig's
-- `lsp/tsc.lua`, which is merged with this file.

return {
	settings = {
		['js/ts'] = {
			-- Hint kinds mirror the gopls/rust-analyzer setups; toggle in the
			-- buffer with `grh`.
			inlayHints = {
				parameterNames = {
					enabled = 'literals',
					suppressWhenArgumentMatchesName = true,
				},
				parameterTypes = {
					enabled = true,
				},
				variableTypes = {
					enabled = true,
				},
				propertyDeclarationTypes = {
					enabled = true,
				},
				functionLikeReturnTypes = {
					enabled = true,
				},
				enumMemberValues = {
					enabled = true,
				},
			},
			-- Code lenses are decorations without an action: the lens runner
			-- keymap is disabled in lua/plugins/lsp.lua. Flip these to true and
			-- re-enable `grx` there to use them.
			referencesCodeLens = {
				enabled = false,
			},
			implementationsCodeLens = {
				enabled = false,
			},
		},
	},
}
