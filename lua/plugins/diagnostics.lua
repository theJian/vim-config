-- diagnostics
local ns = vim.api.nvim_create_namespace 'diagnostics_filtered_signs'

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

vim.diagnostic.handlers.loclist = {
	show = function(_, _, _, opts)
		-- Generally don't want it to open on every update
		opts.loclist.open = opts.loclist.open or false
		local winid = vim.api.nvim_get_current_win()
		vim.diagnostic.setloclist(opts.loclist)
		vim.api.nvim_set_current_win(winid)
	end
}


vim.diagnostic.config {
	virtual_text = false,
	virtual_lines = false,
	severity_sort = true,
	update_in_insert = true,
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = '●',
			[vim.diagnostic.severity.WARN] = '▲',
			[vim.diagnostic.severity.INFO] = '○',
			[vim.diagnostic.severity.HINT] = '⊙',
		},
	},
}
