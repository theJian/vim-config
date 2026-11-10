---@mod ffi.git Asynchronous Git branch lookup through Rust
---@brief [[
---Retrieve Git branch information asynchronously so Neovim can continue working
---during repository lookup. Call require('ffi.git').branch(dir, callback) to run
---the Rust lookup in a worker and receive its result on Neovim's main loop.
---
---To use the Rust implementation, build it with `cargo build --release` before
---importing this module. Importing requires Neovim with LuaJIT FFI and raises an
---error if the library cannot be loaded. See doc/ffi.md for the library override.
---@brief ]]
local M = {}
local loader = require 'ffi.loader'
assert(loader.load())
local pending = {}
local initial_capacity = 256
local max_capacity = 65536

-- libuv workers have separate Lua states; pass declarations and copied values.
local function worker(library, cdef, directory, capacity, limit)
	local buffer_too_small = -2
	local ok, name, diagnostic = pcall(function()
		local ffi = require 'ffi'
		ffi.cdef(cdef)
		local lib = ffi.load(library)
		while capacity <= limit do
			local out = ffi.new('char[?]', capacity)
			local size = lib.ffi_git_branch(directory, out, capacity)
			if size >= 0 then
				return ffi.string(out, size)
			elseif size ~= buffer_too_small then
				return '', 'Git branch lookup failed (native status ' .. tonumber(size) .. ')'
			end
			capacity = capacity * 2
		end
		return '', 'Git branch exceeds the native buffer limit'
	end)
	if not ok then
		return '', tostring(name)
	end
	return name, diagnostic
end

---Request a repository's branch name asynchronously.
---Discover the repository from dir, including parents and linked worktrees.
---Relative paths resolve against the current directory when called.
---Detached HEAD yields a unique commit abbreviation using core.abbrev (default seven digits).
---Unborn HEAD and non-repositories yield an empty string and callback error.
---Invalid argument types or embedded NUL bytes in dir raise an error.
---Queued requests invoke callback on Neovim's main loop and cannot be cancelled.
---@param dir string Directory path.
---@param callback fun(branch: string, error?: string) Receives the branch or an empty string and diagnostic on lookup failure.
---@return boolean queued
---@return string? error Present on worker creation or queue failure; no callback will run.
function M.branch(dir, callback)
	assert(type(dir) == 'string' and not dir:find('\0', 1, true), 'dir must be a path without NUL bytes')
	assert(type(callback) == 'function', 'callback must be a function')
	dir = vim.fn.fnamemodify(dir, ':p')
	local work
	local created, creation_error = pcall(function()
		work = vim.uv.new_work(worker, function(name, diagnostic)
			pending[work] = nil
			vim.schedule(function()
				callback(name, diagnostic)
			end)
		end)
		assert(work, 'could not create native Git worker')
	end)
	if not created then
		return false, tostring(creation_error)
	end
	pending[work] = true
	local ok, result, queue_error =
		pcall(work.queue, work, loader.path, loader.cdef, dir, initial_capacity, max_capacity)
	if not ok or not result then
		pending[work] = nil
		return false, tostring(ok and queue_error or result)
	end
	return true
end

return M
