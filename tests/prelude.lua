package.path = vim.fn.getcwd() .. '/lua/?.lua;' .. package.path

local original_add, original_system, original_load = vim.pack.add, vim.system, vim.pack.load
local commands, additions, installed = {}, {}, {}
local exit_code = 0

local function changed(name, kind)
	vim.api.nvim_exec_autocmds('PackChanged', {
		pattern = '/tmp/' .. name,
		data = { spec = { name = name }, kind = kind, path = '/tmp/' .. name, active = true },
	})
end

vim.pack.add = function(specs)
	additions[#additions + 1] = specs[1]
	local spec = type(specs[1]) == 'string' and { src = specs[1] } or specs[1]
	local name = spec.name or spec.src:gsub('%.git$', ''):match('[^/]+$')
	if not installed[name] then
		installed[name] = true
		changed(name, 'install')
	end
end

vim.system = function(command, opts)
	commands[#commands + 1] = { command = command, cwd = opts.cwd, text = opts.text }
	return { wait = function() return { code = exit_code, stderr = 'compiler output' } end }
end

local ok, err = pcall(function()
	local existing_load = function() return 'existing' end
	local autocmds = vim.api.nvim_get_autocmds { event = 'PackChanged' }
	for _, existing in ipairs { existing_load, false } do
		vim.pack.load = existing
		package.loaded.prelude = nil
		local loaded, failure = pcall(require, 'prelude')
		assert(not loaded and failure:find('prelude: vim.pack.load already exists', 1, true))
		assert(vim.pack.load == existing, 'existing vim.pack.load must be preserved')
		assert(vim.deep_equal(autocmds, vim.api.nvim_get_autocmds { event = 'PackChanged' }),
			'no build hook should be registered when load already exists')
	end
	vim.pack.load = nil
	package.loaded.prelude = nil
	require 'prelude'
	local setup_calls = 0
	local module = { setup = function(opts)
		assert(opts.enabled)
		setup_calls = setup_calls + 1
	end }
	package.preload['prelude-test'] = function()
		assert(#commands == 1, 'initial build must finish before require')
		return module
	end
	vim.pack.load 'https://example.test/first.git'
		.build { 'cargo', 'build' }
		.using 'prelude-test'
		.setup { enabled = true }
	assert(setup_calls == 1)
	assert(vim.deep_equal(commands[1], { command = { 'cargo', 'build' }, cwd = '/tmp/first', text = true }))

	local handle = vim.pack.load 'https://example.test/first.git'
	assert(handle.using 'prelude-test' == module)
	assert(handle.build { 'make' } == handle)
	assert(#commands == 1, 'unchanged package must not rebuild')
	local load = vim.pack.load
	assert(pcall(require, 'prelude'), 'cached require must still succeed')
	package.loaded.prelude = nil
	local reloaded, failure = pcall(require, 'prelude')
	assert(not reloaded and failure:find('prelude: vim.pack.load already exists', 1, true))
	assert(vim.pack.load == load, 'failed reload must preserve the extension and its build registrations')
	changed('unrelated', 'update')
	changed('first', 'delete')
	assert(#commands == 1)
	changed('first', 'update')
	assert(#commands == 2 and commands[2].command[1] == 'make')

	-- Lockfile restoration can happen before the package's load declaration.
	changed('custom', 'install')
	installed.custom = true
	local spec = { src = 'https://example.test/second.git', name = 'custom', version = 'v1', data = { key = true } }
	local command = { 'make', 'release' }
	vim.pack.load(spec).build(command)
	assert(additions[#additions] == spec, 'pass the complete spec through')
	assert(#commands == 3 and commands[3].cwd == '/tmp/custom')
	command[1] = 'changed'
	changed('custom', 'update')
	assert(#commands == 4 and commands[4].command[1] == 'make')

	exit_code = 1
	local built, failure = pcall(function()
		vim.pack.load 'https://example.test/failure'.build { 'false' }
	end)
	assert(not built and failure:find('Failed to build failure', 1, true))
	assert(failure:find('compiler output', 1, true))
	exit_code = 0
	vim.pack.load 'https://example.test/failure'.build { 'true' }
	assert(#commands == 6, 'failed build must remain pending for retry')
	assert(not pcall(handle.build, {}))
	assert(not pcall(handle.build, { 'make', 1 }))
	assert(not pcall(handle.using, 'prelude-nonexistent-module'))
end)

vim.pack.add, vim.system = original_add, original_system
vim.pack.load = original_load
package.preload['prelude-test'], package.loaded['prelude-test'] = nil, nil
assert(ok, err)
print 'PASS: prelude package chaining, builds, events, and errors'
