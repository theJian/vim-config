---Add declarative packages and synchronous install/update builds to native vim.pack.
---Loaded by init.lua before package configuration; requires Neovim's native vim.pack.
---Use vim.pack.use { 'plugin', from = 'https://host/plugin',
---  build = { 'make' } }.setup {}. Omit the module for script-only packages.
---Each call adds the package and returns its optional module. Builds run before
---native plugin scripts on install and on updates; earlier lockfile events wait
---for a declaration with a build. Unchanged packages do not rebuild. Only use is
---added to vim.pack; an existing use field prevents all initialization.
assert(vim.pack.use == nil, 'prelude: vim.pack.use already exists')

local builds, pending, failures = {}, {}, {}

local function validate_command(command)
	assert(type(command) == 'table' and vim.islist(command) and #command > 0, 'build expects an argv list')
	for _, arg in ipairs(command) do
		assert(type(arg) == 'string', 'build arguments must be strings')
	end
end

local function package_name(spec)
	local name = spec.name or spec.src:gsub('%.git$', '')
	name = (type(name) == 'string' and name or ''):match('[^/]+$') or ''
	assert(name ~= '', 'spec.name must resolve to a non-empty string')
	return name
end

local function run_build(data)
	local name = data.spec.name
	local command = builds[name]
	if not command then
		return
	end
	local ok, err = pcall(function()
		local result = vim.system(command, { cwd = data.path, text = true }):wait()
		if result.code ~= 0 then
			error(('Failed to build %s (exit %s): %s'):format(
				name, result.code, result.stderr or result.stdout or ''
			))
		end
	end)
	if not ok then
		failures[name] = err
		error(err)
	end
	pending[name], failures[name] = nil, nil
end

vim.api.nvim_create_autocmd('PackChanged', {
	group = vim.api.nvim_create_augroup('PreludePack', { clear = true }),
	callback = function(ev)
		local data = ev.data
		if data.kind ~= 'install' and data.kind ~= 'update' then
			if data.kind == 'delete' then
				pending[data.spec.name], failures[data.spec.name] = nil, nil
			end
			return
		end
		-- Native add can restore other lockfile packages before their declarations.
		pending[data.spec.name] = data
		run_build(data)
	end,
})

---@class PreludePackage
---@field [1]? string Non-empty module name, required after native add and builds.
---@field from string Non-empty package URL.
---@field name? string Native package name; defaults to the URL basename without .git.
---@field version? string|vim.VersionRange Native version constraint.
---@field data? any Native package metadata.
---@field build? string[] Non-empty command argv, executed without a shell.
---@field load? boolean|fun(plug: vim.pack.PlugData) Native add loading option.
---@field confirm? boolean Native add confirmation option.

---Add one package and return require(declaration[1]), or nil without a module.
---Omitted load/confirm retain native defaults, including when both are omitted.
---Copies build argv and leaves the declaration unchanged. A supplied build replaces
---the package's session registration and immediately retries any pending event.
---Install/update builds wait in the package directory; unchanged packages do not
---rebuild. Native add or build errors prevent require; require errors propagate.
---Each explicit call requires its module, including load=false; the require cache
---applies normally. Updates only run builds. Native vim.pack fields are preserved.
---@param declaration PreludePackage
---@return any module
function vim.pack.use(declaration)
	assert(type(declaration) == 'table', 'use expects a package declaration')
	local fields = { [1] = true, from = true, name = true, version = true, data = true,
		build = true, load = true, confirm = true }
	for field in pairs(declaration) do
		assert(fields[field], 'unknown package declaration field: ' .. tostring(field))
	end
	assert(declaration[1] == nil or (type(declaration[1]) == 'string' and declaration[1] ~= ''),
		'module must be a non-empty string')
	assert(type(declaration.from) == 'string' and declaration.from ~= '', 'from must be a non-empty package URL')
	local spec = { src = declaration.from, name = declaration.name, version = declaration.version, data = declaration.data }
	local name = package_name(spec)
	local version = spec.version
	assert(version == nil or type(version) == 'string'
		or (type(version) == 'table' and pcall(version.has, version, '1')), 'version must be a string or vim.VersionRange')
	assert(declaration.load == nil or type(declaration.load) == 'boolean' or type(declaration.load) == 'function',
		'load must be a boolean or function')
	assert(declaration.confirm == nil or type(declaration.confirm) == 'boolean', 'confirm must be a boolean')
	if declaration.build ~= nil then
		validate_command(declaration.build)
	end

	local opts
	if declaration.load ~= nil or declaration.confirm ~= nil then
		opts = { load = declaration.load, confirm = declaration.confirm }
	end
	if declaration.build then
		builds[name] = vim.deepcopy(declaration.build)
		if pending[name] then
			run_build(pending[name])
		end
	end
	vim.pack.add({ spec }, opts)
	-- Native autocmd dispatch reports callback errors without throwing to add.
	if failures[name] then
		error(failures[name])
	end
	if declaration[1] then
		return require(declaration[1])
	end
end

return {}
