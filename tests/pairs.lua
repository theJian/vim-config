-- Check pairing startup and update orchestration without packages or compilers.
-- In particular, native lock restoration may precede the pairing build hook.
local source = vim.fn.getcwd() .. '/after/plugin/pairs.lua'
local original_add, original_packadd = vim.pack.add, vim.cmd.packadd
local original_pairs, original_preload = package.loaded['blink.pairs'], package.preload['blink.pairs']
local helper_available, pairs_available, library_available, fail_build
local builds, setups, loads, hook_errors

local function changed(name, kind, active)
	for _, hook in ipairs(vim.api.nvim_get_autocmds { event = 'PackChanged', group = 'BlinkPairsBuild' }) do
		local ok, err = pcall(hook.callback, {
			data = { spec = { name = name }, kind = kind, active = active },
		})
		if not ok then
			hook_errors[#hook_errors + 1] = err
		end
	end
end

local function reset(mode)
	pcall(vim.api.nvim_del_augroup_by_name, 'BlinkPairsBuild')
	helper_available, pairs_available = false, false
	library_available, fail_build = mode == 'warm', mode == 'failure'
	builds, setups, loads, hook_errors = 0, 0, 0, {}
	package.loaded['blink.pairs'] = nil
	package.preload['blink.pairs'] = function()
		assert(helper_available, 'blink.lib must be available before requiring pairs')
		assert(pairs_available, 'Inactive pairs must be loaded before its build')
		return {
			build = function()
				return {
					wait = function()
						if library_available then
							return
						end
						builds = builds + 1
						assert(not fail_build, 'native compiler failed')
						library_available = true
					end,
				}
			end,
			setup = function()
				assert(library_available, 'Setup must wait for a usable native library')
				setups = setups + 1
			end,
		}
	end
	vim.cmd.packadd = function(name)
		assert(name == 'blink.pairs')
		pairs_available = true
		loads = loads + 1
	end
	vim.pack.add = function(specs)
		if specs[1] == 'https://github.com/saghen/blink.lib' then
			-- Native add may restore all lockfile packages before this add returns.
			if mode == 'restored' then
				pairs_available = true
			end
			helper_available = true
		elseif specs[1] == 'https://github.com/saghen/blink.pairs' then
			if mode == 'cold' or mode == 'failure' then
				changed('blink.pairs', 'install', false)
			end
			pairs_available = true
		else
			error('Unexpected package: ' .. tostring(specs[1]))
		end
	end
end

local ok, err = xpcall(function()
	for _, mode in ipairs { 'cold', 'restored', 'warm' } do
		reset(mode)
		dofile(source)
		assert(setups == 1 and #hook_errors == 0, mode .. ': startup failed')
		assert(builds == (mode == 'warm' and 0 or 1), mode .. ': incorrect build count')
		assert(loads == (mode == 'cold' and 1 or 0), mode .. ': inactive load handling')
	end

	-- Existing source-only installs also need the pre-setup build check.
	reset 'missing'
	dofile(source)
	assert(builds == 1 and setups == 1)
	library_available, pairs_available = false, false
	changed('blink.pairs', 'update', false)
	assert(builds == 2 and loads == 1 and setups == 1, 'Update must build without repeating setup')
	changed('blink.pairs', 'delete', false)
	changed('other', 'update', false)
	assert(builds == 2, 'Unrelated and delete events must not build')

	library_available, fail_build = false, true
	changed('blink.pairs', 'update', true)
	assert(#hook_errors == 1 and hook_errors[1]:find('native compiler failed', 1, true))
	assert(setups == 1, 'Failed update must not repeat setup')

	reset 'failure'
	local started, failure = pcall(dofile, source)
	assert(not started and failure:find('native compiler failed', 1, true))
	assert(#hook_errors == 1, 'Native add can report hook failures without throwing')
	assert(setups == 0, 'A swallowed hook failure must still prevent setup')
	print 'Verified pairing cold/restored/warm startup, missing libraries, updates, and build failures.'
end, debug.traceback)

vim.pack.add, vim.cmd.packadd = original_add, original_packadd
package.loaded['blink.pairs'], package.preload['blink.pairs'] = original_pairs, original_preload
pcall(vim.api.nvim_del_augroup_by_name, 'BlinkPairsBuild')
assert(ok, err)
vim.cmd.qa()
