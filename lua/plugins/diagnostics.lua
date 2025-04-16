-- diagnostics
local ns = vim.api.nvim_create_namespace'diagnostics_filtered_signs'

-- Get a reference to the original signs handler
local orig_signs_handler = vim.diagnostic.handlers.signs
-- Override the built-in signs handler
vim.diagnostic.handlers.signs = {
	show = function(_, bufnr, _, opts)
	  -- Get all diagnostics from the whole buffer rather than just the
	  -- diagnostics passed to the handler
	  local diagnostics = vim.diagnostic.get(bufnr)

	  -- Find the "worst" diagnostic per line
	  local max_severity_per_line = {}
	  for _, d in pairs(diagnostics) do
		 local m = max_severity_per_line[d.lnum]
		 if not m or d.severity < m.severity then
			max_severity_per_line[d.lnum] = d
		 end
	  end

	  -- Pass the filtered diagnostics (with our custom namespace) to
	  -- the original handler
	  local filtered_diagnostics = vim.tbl_values(max_severity_per_line)
	  orig_signs_handler.show(ns, bufnr, filtered_diagnostics, opts)
	end,
	hide = function(_, bufnr)
	  orig_signs_handler.hide(ns, bufnr)
	end,
}

vim.diagnostic.config({
	virtual_text = false,
	virtual_lines = false,
	sign = true,
	severity_sort = true,
})

vim.fn.sign_define({
	{ name = 'DiagnosticSignError', text = '●', texthl = 'DiagnosticSignError' },
	{ name = 'DiagnosticSignWarn', text = '●', texthl = 'DiagnosticSignWarn' },
	{ name = 'DiagnosticSignInfo', text = '○', texthl = 'DiagnosticSignInfo' },
	{ name = 'DiagnosticSignHint', text = '⊙', texthl = 'DiagnosticSignHint' },
})

