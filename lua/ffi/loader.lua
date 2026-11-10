---@mod ffi.loader Rust shared-library loading for native Lua wrappers
---@brief [[
---This module loads the Rust shared library used by native Lua wrappers such as
---ffi.git. Wrappers call load() for a local handle and use the exported path and
---C declarations to let libuv workers load their own handles in separate Lua states.
---
---Build the library with `cargo build --release` before calling load(), which
---requires LuaJIT FFI. The first result is cached. If load() has already run,
---restart Neovim after building or replacing the library.
---@brief ]]
local M = {}
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local filename = jit and jit.os == 'Windows' and 'ffi.dll'
	or ('libffi.' .. (jit and jit.os == 'OSX' and 'dylib' or 'so'))
---Library path used by load() and isolated workers. Defaults to the absolute
---platform-specific library path under this repository's target/release directory.
---NVIM_NATIVE_LIBRARY overrides that default when this module is imported.
---@type string
M.path = vim.env.NVIM_NATIVE_LIBRARY or (root .. '/target/release/' .. filename)
---C declarations registered by load() and passed to workers for registration in
---their separate LuaJIT states.
---@type string
M.cdef = [[
	int32_t ffi_git_branch(const char *path, char *out, size_t capacity);
]]
local handle, failure

---Load the library at path and check its ffi_git_branch symbol on the first call.
---Return the handle, or nil and a diagnostic on failure. Both outcomes are cached,
---so later calls do not retry. Requires LuaJIT FFI.
---@return ffi.namespace*? library
---@return string? error
function M.load()
	if handle or failure then
		return handle, failure
	end
	local ok, result = pcall(function()
		local ffi = require 'ffi'
		ffi.cdef(M.cdef)
		local lib = ffi.load(M.path)
		assert(lib.ffi_git_branch, 'native library is missing the Git branch symbol')
		return lib
	end)
	if ok then
		handle = result
	else
		failure = ('Cannot load Rust library %s: %s. Run cargo build --release and restart Neovim.'):format(
			M.path,
			result
		)
	end
	return handle, failure
end

return M
