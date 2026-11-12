---@mod ffi.git Asynchronous Git branch and status lookup through Rust
---@brief [[
---Retrieve Git information asynchronously so Neovim can continue working
---during repository lookup. Call require('ffi.git').status(dir, callback) to run
---the Rust lookup in a worker and receive its result on Neovim's main loop.
---
---To use the Rust implementation, build it with `cargo build --release` before
---importing this module. Importing requires Neovim with LuaJIT FFI and raises an
---error if the library cannot be loaded. See |better-start-nvim-ffi-build| for
---the library override.
---@brief ]]
local M = {}
local loader = require 'ffi.loader'
assert(loader.load())
local pending = {}
local initial_capacity = 256
local max_capacity = 65536

-- libuv workers have separate Lua states; pass declarations and copied values.
local function worker(library, cdef, directory, capacity, limit, include_status)
	local buffer_too_small = -2
	local ok, name, diagnostic, tracked, untracked, ahead, behind, conflicts = pcall(function()
		local ffi = require 'ffi'
		ffi.cdef(cdef)
		local lib = ffi.load(library)
		local counts = include_status and ffi.new 'FfiGitCounts[1]'
		while capacity <= limit do
			local out = ffi.new('char[?]', capacity)
			local size = include_status and lib.ffi_git_status(directory, out, capacity, counts)
				or lib.ffi_git_branch(directory, out, capacity)
			if size >= 0 then
				if include_status then
					local c = counts[0]
					-- libuv workers can return primitives, not tables or FFI cdata.
					return ffi.string(out, size),
						nil,
						tonumber(c.tracked),
						tonumber(c.untracked),
						tonumber(c.ahead),
						tonumber(c.behind),
						tonumber(c.conflicts)
				end
				return ffi.string(out, size)
			elseif size ~= buffer_too_small then
				return '', 'Git lookup failed (native status ' .. tonumber(size) .. ')'
			end
			capacity = capacity * 2
		end
		return '', 'Git branch exceeds the native buffer limit'
	end)
	if not ok then
		return '', tostring(name)
	end
	return name, diagnostic, tracked, untracked, ahead, behind, conflicts
end

local function request(dir, callback, include_status)
	assert(type(dir) == 'string' and not dir:find('\0', 1, true), 'dir must be a path without NUL bytes')
	assert(type(callback) == 'function', 'callback must be a function')
	dir = vim.fn.fnamemodify(dir, ':p')
	local work
	local created, creation_error = pcall(function()
		work = vim.uv.new_work(worker, function(name, diagnostic, tracked, untracked, ahead, behind, conflicts)
			pending[work] = nil
			vim.schedule(function()
				if include_status then
					local result
					if not diagnostic then
						result = {
							branch = name,
							tracked = tracked,
							untracked = untracked,
							ahead = ahead,
							behind = behind,
							conflicts = conflicts,
						}
					end
					callback(result, diagnostic)
				else
					callback(name, diagnostic)
				end
			end)
		end)
		assert(work, 'could not create native Git worker')
	end)
	if not created then
		return false, tostring(creation_error)
	end
	pending[work] = true
	local ok, result, queue_error =
		pcall(work.queue, work, loader.path, loader.cdef, dir, initial_capacity, max_capacity, include_status)
	if not ok or not result then
		pending[work] = nil
		return false, tostring(ok and queue_error or result)
	end
	return true
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
	return request(dir, callback, false)
end

---@class FfiGitStatus
---@field branch string Branch name (including unborn branches) or detached commit ID.
---@field tracked integer Changed tracked files, staged or unstaged, excluding conflicts.
---@field untracked integer Untracked files, including individual files in new directories; excludes ignored files.
---@field ahead integer Commits ahead of the locally known upstream, or zero without one.
---@field behind integer Commits behind the locally known upstream, or zero without one.
---@field conflicts integer Conflicted files; each file appears in only one file count.

---Request repository-wide file counts and branch/upstream information asynchronously.
---Uses branch()'s discovery, path, queueing, and callback rules. Supports unborn HEAD.
---Counts saved changes only; never fetches or spawns Git commands.
---@param dir string Directory path.
---@param callback fun(status: FfiGitStatus?, error?: string) Receives nil and a diagnostic on lookup failure.
---@return boolean queued
---@return string? error Present on worker creation or queue failure; no callback will run.
function M.status(dir, callback)
	return request(dir, callback, true)
end

return M
