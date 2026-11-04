-- Exercise declarative packages without downloads, plugin loading, or compilers.
-- Native add dispatches install events before scripts and swallows hook errors.
package.path = vim.fn.getcwd() .. '/lua/?.lua;' .. package.path

local original = { add = vim.pack.add, system = vim.system, use = vim.pack.use, build = vim.pack.build }
local commands, additions, installed, scripts, event_errors = {}, {}, {}, {}, {}
local exit_code, add_error, system_error = 0, nil, nil
local setups, module_loads, require_attempts = 0, 0, 0

local function changed(name, kind)
	if kind == 'install' then installed[name] = true end
	if kind == 'delete' then installed[name] = nil end
	local data = { spec = { name = name }, kind = kind, path = '/tmp/' .. name, active = true }
	for _, hook in ipairs(vim.api.nvim_get_autocmds { event = 'PackChanged' }) do
		local ok, err = pcall(hook.callback, { data = data })
		if not ok then event_errors[#event_errors + 1] = err end
	end
end

local function build_count(name)
	local count = 0
	for _, command in ipairs(commands) do
		if command.cwd == '/tmp/' .. name then count = count + 1 end
	end
	return count
end

local function setup(...)
	assert(select('#', ...) == 0)
	setups = setups + 1
end

vim.pack.add = function(specs, opts)
	assert(not add_error, add_error)
	assert(#specs == 1)
	local spec = specs[1]
	additions[#additions + 1] = { source = spec, opts = opts }
	local name = (spec.name or spec.src:gsub('%.git$', '')):match('[^/]+$')
	if not installed[name] then
		installed[name] = true
		changed(name, 'install')
	end
	if opts and type(opts.load) == 'function' then
		opts.load { spec = spec, path = '/tmp/' .. name }
	elseif not opts or opts.load ~= false then
		if scripts[name] then scripts[name]() end
	end
end

vim.system = function(command, opts)
	assert(not system_error, system_error)
	commands[#commands + 1] = { command = vim.deepcopy(command), cwd = opts.cwd, text = opts.text }
	return { wait = function() return { code = exit_code, stderr = 'compiler output' } end }
end
package.preload['prelude-test'] = function()
	module_loads = module_loads + 1
	return { setup = setup }
end

package.preload['tracked-module'] = function()
	require_attempts = require_attempts + 1
	return {}
end

local ok, err = xpcall(function()
	local autocmds = vim.api.nvim_get_autocmds { event = 'PackChanged' }
	for _, existing in ipairs { function() end, false } do
		vim.pack.use = existing
		package.loaded.prelude = nil
		local loaded, failure = pcall(require, 'prelude')
		assert(not loaded and failure:find('prelude: vim.pack.use already exists', 1, true))
		assert(vim.pack.use == existing and vim.pack.build == original.build)
		assert(vim.deep_equal(autocmds, vim.api.nvim_get_autocmds { event = 'PackChanged' }),
			'collision must not register or replace build hooks')
	end
	vim.pack.use = nil
	local native_build = function() error 'native build must remain untouched' end
	vim.pack.build = native_build
	package.loaded.prelude = nil
	local prelude = require 'prelude'
	assert(vim.pack.build == native_build, 'existing native build field must be preserved')
	local use = vim.pack.use
	assert(require 'prelude' == prelude, 'cached require must succeed')
	package.loaded.prelude = nil
	assert(not pcall(require, 'prelude'))
	assert(vim.pack.use == use and vim.pack.build == native_build)

	local order = {}
	scripts.first = function()
		assert(build_count('first') == 1, 'build must precede native scripts')
		order[#order + 1] = 'scripts'
	end
	package.preload['first-module'] = function()
		assert(vim.deep_equal(order, { 'scripts' }), 'native scripts must precede require')
		require_attempts = require_attempts + 1
		return require 'prelude-test'
	end
	local declaration = { 'first-module', from = 'https://example.test/first.git', build = { 'cargo', 'build' } }
	local snapshot = vim.deepcopy(declaration)
	local result = vim.pack.use(declaration)
	assert(result == require('prelude-test'), 'use must return the required module')
	result.setup()
	assert(vim.deep_equal(snapshot, declaration), 'declaration must remain unchanged')
	assert(vim.deep_equal(commands[1], { command = { 'cargo', 'build' }, cwd = '/tmp/first', text = true }))
	assert(vim.deep_equal(additions[1].source, { src = declaration.from }), 'extension fields must not reach native spec')
	assert(additions[1].opts == nil and setups == 1 and module_loads == 1 and require_attempts == 1)
	declaration.build[1] = 'mutated'
	changed('first', 'update')
	assert(commands[#commands].command[1] == 'cargo', 'registered argv must be copied')
	assert(setups == 1 and require_attempts == 1, 'updates must not require modules or replay setup')
	scripts.first = nil

	assert(vim.pack.use { 'first-module', from = declaration.from } == result)
	assert(additions[#additions].opts == nil and require_attempts == 1, 'require must use its cache')
	for _, load in ipairs { true, false } do
		package.loaded['first-module'] = nil
		package.preload['first-module'] = function()
			require_attempts = require_attempts + 1
			return result
		end
		assert(vim.pack.use { 'first-module', from = declaration.from, load = load, confirm = false } == result)
		assert(vim.deep_equal(additions[#additions].opts, { load = load, confirm = false }))
	end
	assert(require_attempts == 3, 'load=false must still require the module')
	local callback_loaded = false
	local load_callback = function(plug)
		assert(plug.spec.src == declaration.from)
		callback_loaded = true
	end
	package.loaded['first-module'] = nil
	package.preload['first-module'] = function()
		assert(callback_loaded, 'native load callback must finish before require')
		return result
	end
	assert(vim.pack.use { 'first-module', from = declaration.from, load = load_callback } == result)
	assert(additions[#additions].opts.load == load_callback and additions[#additions].opts.confirm == nil)
	vim.pack.use { from = declaration.from, confirm = true }
	assert(vim.deep_equal(additions[#additions].opts, { confirm = true }))
	assert(build_count('first') == 2, 'explicit calls must not rebuild unchanged packages')
	assert(setups == 1, 'use must leave setup to its caller')

	vim.pack.use { from = 'https://example.test/native-defaults.git', name = false, data = false }
	assert(vim.deep_equal(additions[#additions].source,
		{ src = 'https://example.test/native-defaults.git', name = false, data = false }))

	-- Lockfile restoration can install a package before its build is declared.
	changed('custom.git', 'install')
	installed['custom.git'] = true
	local range = vim.version.range('1.0')
	local spec = { from = 'https://example.test/second.git', name = 'path/custom.git', version = range,
		data = { key = true }, build = { 'make', 'release' } }
	snapshot = vim.deepcopy(spec)
	scripts['custom.git'] = function() assert(build_count('custom.git') == 1) end
	vim.pack.use(spec)
	assert(vim.deep_equal(spec, snapshot))
	assert(vim.deep_equal(additions[#additions].source,
		{ src = spec.from, name = spec.name, version = range, data = spec.data }))
	assert(commands[#commands].cwd == '/tmp/custom.git', 'explicit names use native basename normalization')
	local required = require_attempts
	changed('custom.git', 'update')
	assert(build_count('custom.git') == 2 and require_attempts == required)

	package.preload['script-only'] = function() error 'script-only package must not be required' end
	assert(vim.pack.use { from = 'https://example.test/script-only', build = { 'make' }, version = 'v1', load = false } == nil)
	assert(module_loads == 1, 'declarations without a module must require nothing')
	vim.pack.use { from = 'https://example.test/script-only', build = { 'replacement' }, load = false }
	assert(build_count('script-only') == 1, 'replacement must not rebuild an unchanged package')
	changed('script-only', 'update')
	assert(commands[#commands].command[1] == 'replacement')
	changed('deleted', 'install')
	changed('deleted', 'delete')
	vim.pack.use { from = 'https://example.test/deleted', build = { 'make' } }
	assert(build_count('deleted') == 1, 'delete must clear the earlier pending event')
	changed('deleted', 'delete')
	changed('deleted', 'install')
	assert(build_count('deleted') == 2, 'delete must preserve session build registration')
	changed('unrelated', 'update')
	assert(build_count('unrelated') == 0)

	exit_code = 1
	package.loaded['tracked-module'] = nil
	required = require_attempts
	local built, failure = pcall(vim.pack.use, { from = 'https://example.test/failure', build = { 'false' }, [1] = 'tracked-module' })
	assert(not built and failure:find('Failed to build failure', 1, true) and failure:find('compiler output', 1, true))
	assert(#event_errors > 0 and require_attempts == required, 'swallowed native build errors must prevent require')
	assert(not pcall(vim.pack.use, { from = 'https://example.test/failure', [1] = 'tracked-module' }),
		'a prior registered build failure must block require even without a build field')
	exit_code = 0
	vim.pack.use { from = 'https://example.test/failure', build = { 'true' }, [1] = 'tracked-module' }
	assert(build_count('failure') == 2 and require_attempts == required + 1, 'pending failures must retry')

	changed('pending-failure', 'install')
	exit_code = 1
	local before = #additions
	assert(not pcall(vim.pack.use, { from = 'https://example.test/pending-failure', build = { 'false' }, [1] = 'tracked-module' }))
	assert(#additions == before, 'failed pending build must stop before native add')
	exit_code = 0
	vim.pack.use { from = 'https://example.test/pending-failure', build = { 'true' } }
	assert(build_count('pending-failure') == 2, 'failed pending build must be retried')

	exit_code = 1
	assert(not pcall(vim.pack.use, { from = 'https://example.test/delete-failure', build = { 'false' } }))
	changed('delete-failure', 'delete')
	exit_code = 0
	package.loaded['tracked-module'] = nil
	vim.pack.use { from = 'https://example.test/delete-failure', [1] = 'tracked-module' }
	assert(require_attempts == required + 2, 'delete must clear previous build failure')
	exit_code = 0

	-- All declaration validation precedes registration, pending builds, and add.
	changed('invalid', 'install')
	for _, invalid in ipairs {
		false, '', 1, {}, { '' }, { false }, { 'old-url-only' },
		{ from = '' }, { from = false }, { from = {} },
		{ '', from = 'https://example.test/invalid', build = { 'make' } },
		{ false, from = 'https://example.test/invalid', build = { 'make' } },
		{ {}, from = 'https://example.test/invalid', build = { 'make' } },
		{ 'module', 'extra', from = 'https://example.test/invalid', build = { 'make' } },
		{ src = 'https://example.test/invalid', from = 'https://example.test/invalid', build = { 'make' } },
		{ from = 'https://example.test/invalid', name = 1 }, { from = 'https://example.test/invalid', name = '/' },
		{ from = 'https://example.test/invalid', version = false }, { from = 'https://example.test/invalid', version = {} },
		{ from = 'https://example.test/invalid', build = {} }, { from = 'https://example.test/invalid', build = { 'make', 1 } },
		{ from = 'https://example.test/invalid', build = { key = 'make' } }, { from = 'https://example.test/invalid', build = false },
		{ from = 'https://example.test/invalid', build = 'make' }, { from = 'https://example.test/invalid', config = function() end, build = { 'make' } },
		{ from = 'https://example.test/invalid', load = 'yes', build = { 'make' } },
		{ from = 'https://example.test/invalid', confirm = 0, build = { 'make' } },
		{ from = 'https://example.test/invalid', unknown = true, build = { 'make' } },
	} do
		local added, built_count, requires = #additions, #commands, require_attempts
		assert(not pcall(vim.pack.use, invalid))
		assert(#additions == added and #commands == built_count and require_attempts == requires)
	end
	changed('invalid', 'update')
	assert(build_count('invalid') == 0, 'invalid declarations must not register builds')

	package.loaded['tracked-module'] = nil
	add_error = 'native add failure'
	required = require_attempts
	local added, failure_message = pcall(vim.pack.use, { from = 'https://example.test/blocked', [1] = 'tracked-module' })
	assert(not added and failure_message:find(add_error, 1, true) and require_attempts == required)
	add_error = nil
	system_error = 'spawn failure'
	local spawned, spawn_error = pcall(vim.pack.use, { from = 'https://example.test/spawn', build = { 'make' }, [1] = 'tracked-module' })
	assert(not spawned and spawn_error:find(system_error, 1, true) and require_attempts == required)
	system_error = nil
	package.preload['broken-module'] = function() error 'require failure' end
	local loaded, require_error = pcall(vim.pack.use, { 'broken-module', from = 'https://example.test/broken' })
	assert(not loaded and require_error:find('require failure', 1, true), 'require errors must propagate')
	local missing, missing_error = pcall(vim.pack.use, { 'missing-prelude-module', from = 'https://example.test/missing' })
	assert(not missing and missing_error:find("module 'missing-prelude-module' not found", 1, true))
end, debug.traceback)

vim.pack.add, vim.system, vim.pack.use, vim.pack.build = original.add, original.system, original.use, original.build
for _, name in ipairs { 'prelude-test', 'prelude', 'first-module', 'tracked-module', 'broken-module', 'script-only' } do
	package.preload[name], package.loaded[name] = nil, nil
end
assert(ok, err)
print 'PASS: prelude declarations, build timing, native forwarding, lifecycle, and errors'
