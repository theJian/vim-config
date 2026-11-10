-- Search files and their contents with fff.nvim. Check the native backend at
-- startup because lock restoration can install it before its build hook exists.
local function ensure_backend(force)
	local loaded = pcall(require, 'fff.rust')
	if loaded and not force then
		return
	end
	if not loaded then
		package.loaded['fff.rust'] = nil
	end
	require('fff.download').download_or_build_binary()
	require 'fff.rust'
end

vim.api.nvim_create_autocmd('PackChanged', {
	group = vim.api.nvim_create_augroup('FffBackend', { clear = true }),
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		if name == 'fff.nvim' and (kind == 'install' or kind == 'update') then
			if not ev.data.active then
				vim.cmd.packadd 'fff.nvim'
			end
			ensure_backend(true)
		end
	end,
})

vim.pack.add { 'https://github.com/dmtrKovalenko/fff.nvim' }
ensure_backend(false)

vim.g.fff = {
	lazy_sync = true,
	debug = { enabled = true, show_scores = true },
}

vim.keymap.set('n', '<leader>f', function()
	require('fff').find_files()
end, { desc = 'FFFind files' })

vim.keymap.set('n', '<leader>g', function()
	require('fff').live_grep()
end, { desc = 'FFFind grep' })
