assert(vim.pack.load == nil, 'prelude: vim.pack.load already exists')

local builds, pending = {}, {}

local function run_build(data)
	local command = builds[data.spec.name]
	if not command then
		return
	end
	local result = vim.system(command, { cwd = data.path, text = true }):wait()
	if result.code ~= 0 then
		error(('Failed to build %s (exit %s): %s'):format(
			data.spec.name, result.code, result.stderr or result.stdout or ''
		))
	end
	pending[data.spec.name] = nil
end

vim.api.nvim_create_autocmd('PackChanged', {
	group = vim.api.nvim_create_augroup('PreludePack', { clear = true }),
	callback = function(ev)
		local data = ev.data
		if data.kind ~= 'install' and data.kind ~= 'update' then
			if data.kind == 'delete' then
				pending[data.spec.name] = nil
			end
			return
		end
		-- The first add can also install other packages from the lockfile.
		pending[data.spec.name] = data
		run_build(data)
	end,
})

---@class PreludePackage
---@field build fun(command: string[]): PreludePackage
---@field using fun(module: string): any

---Install and add a package using native vim.pack defaults.
---@param source string|vim.pack.Spec
---@return PreludePackage
function vim.pack.load(source)
	vim.pack.add { source }
	local spec = type(source) == 'string' and { src = source } or source
	local name = (spec.name or spec.src:gsub('%.git$', '')):match('[^/]+$')
	local handle = {}

	function handle.build(command)
		assert(type(command) == 'table' and vim.islist(command) and #command > 0, 'build expects an argv list')
		for _, arg in ipairs(command) do
			assert(type(arg) == 'string', 'build arguments must be strings')
		end
		builds[name] = vim.deepcopy(command)
		if pending[name] then
			run_build(pending[name])
		end
		return handle
	end

	function handle.using(module)
		return require(module)
	end

	return handle
end

return {}
