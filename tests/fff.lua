-- Verify backend readiness and rebuild events without downloads or native code.
-- Failed Lua requires retain a sentinel, so recovery must allow a real retry.
local source = vim.fn.getcwd() .. '/after/plugin/fff.lua'
local original_add, original_packadd = vim.pack.add, vim.cmd.packadd
local original = {}
for _, name in ipairs { 'fff', 'fff.rust', 'fff.download' } do
	original[name] = { loaded = package.loaded[name], preload = package.preload[name] }
end
local plugin_loaded, backend_ready, download_error, broken_download
local downloads, backend_loads, loads, file_pickers, grep_pickers, hook_errors

local function changed(name, kind, active)
	for _, hook in ipairs(vim.api.nvim_get_autocmds { event = 'PackChanged', group = 'FffBackend' }) do
		local ok, err = pcall(hook.callback, {
			data = { spec = { name = name }, kind = kind, active = active },
		})
		if not ok then
			hook_errors[#hook_errors + 1] = err
		end
	end
end

local function reset(mode)
	pcall(vim.api.nvim_del_augroup_by_name, 'FffBackend')
	pcall(vim.keymap.del, 'n', '<leader>f')
	pcall(vim.keymap.del, 'n', '<leader>g')
	plugin_loaded, backend_ready = false, mode == 'warm'
	download_error, broken_download = mode == 'cold-failure', mode == 'broken-download'
	downloads, backend_loads, loads, file_pickers, grep_pickers, hook_errors = 0, 0, 0, 0, 0, {}
	for name in pairs(original) do
		package.loaded[name] = nil
	end
	package.preload['fff.rust'] = function()
		assert(plugin_loaded, 'Inactive fff must be loaded before backend preparation')
		backend_loads = backend_loads + 1
		assert(backend_ready, 'invalid or missing native library')
		return {}
	end
	package.preload['fff.download'] = function()
		return {
			download_or_build_binary = function()
				downloads = downloads + 1
				if not backend_ready then
					assert(package.loaded['fff.rust'] == nil, 'Failed require sentinel must be cleared')
				end
				assert(not download_error, 'download and build failed')
				if not broken_download then
					backend_ready = true
				end
			end,
		}
	end
	package.preload.fff = function()
		return {
			find_files = function()
				file_pickers = file_pickers + 1
			end,
			live_grep = function()
				grep_pickers = grep_pickers + 1
			end,
		}
	end
	vim.cmd.packadd = function(name)
		assert(name == 'fff.nvim')
		plugin_loaded, loads = true, loads + 1
	end
	vim.pack.add = function(specs)
		assert(specs[1] == 'https://github.com/dmtrKovalenko/fff.nvim')
		if mode == 'cold' or mode == 'cold-failure' then
			changed('fff.nvim', 'install', false)
		end
		plugin_loaded = true
	end
end

local ok, err = xpcall(function()
	for _, mode in ipairs { 'warm', 'cold', 'restored', 'invalid' } do
		reset(mode)
		dofile(source)
		assert(#hook_errors == 0 and backend_ready, mode .. ': backend unavailable')
		assert(downloads == (mode == 'warm' and 0 or 1), mode .. ': duplicate or missing preparation')
		assert(backend_loads == (mode == 'warm' and 1 or 2), mode .. ': backend must actually load')
		assert(loads == (mode == 'cold' and 1 or 0), mode .. ': incorrect inactive loading')
		assert(file_pickers == 0 and grep_pickers == 0, 'Startup must not open a picker')
	end

	reset 'warm'
	dofile(source)
	local find = vim.fn.maparg('<leader>f', 'n', false, true).callback
	local grep = vim.fn.maparg('<leader>g', 'n', false, true).callback
	changed('fff.nvim', 'update', true)
	assert(downloads == 1, 'Updates must rebuild even when the backend is already loaded')
	assert(vim.fn.maparg('<leader>f', 'n', false, true).callback == find, 'Update must preserve picker mappings')
	assert(file_pickers == 0 and grep_pickers == 0, 'Updates must not initialize a picker')
	find()
	grep()
	assert(file_pickers == 1 and grep_pickers == 1, 'File and content search mappings must remain usable')
	changed('fff.nvim', 'delete', false)
	changed('other', 'update', false)
	assert(downloads == 1, 'Unrelated or delete events must not rebuild')

	for _, mode in ipairs { 'cold-failure', 'broken-download' } do
		reset(mode)
		local started, failure = pcall(dofile, source)
		assert(not started, mode .. ': failed backend preparation must stop configuration')
		assert(
			failure:find(
				mode == 'cold-failure' and 'download and build failed' or 'invalid or missing native library',
				1,
				true
			)
		)
		assert(vim.fn.maparg('<leader>f', 'n') == '' and vim.fn.maparg('<leader>g', 'n') == '')
	end
	print 'Verified fff warm/cold/restored startup, loader retries, updates, search mappings, and failures.'
end, debug.traceback)

vim.pack.add, vim.cmd.packadd = original_add, original_packadd
for name, state in pairs(original) do
	package.loaded[name], package.preload[name] = state.loaded, state.preload
end
pcall(vim.api.nvim_del_augroup_by_name, 'FffBackend')
assert(ok, err)
vim.cmd.qa()
