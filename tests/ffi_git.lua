-- Check the compiled ABI and public asynchronous Lua API without loading configured
-- plugins. Git fixtures stay in temporary repositories.
-- Run after cargo build --release with nvim --headless -u NONE -i NONE -l tests/ffi_git.lua.
vim.opt.rtp:prepend(vim.fn.getcwd())
local ffi = require 'ffi'
local ffi_git = require 'ffi.git'
local loader = require 'ffi.loader'
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, 'p')
local function git(dir, ...)
	local args = { 'git', '-C', dir }
	vim.list_extend(args, { ... })
	local result = vim.system(args, { text = true }):wait()
	assert(result.code == 0, result.stderr)
	return vim.trim(result.stdout)
end
local function branch(dir, expected, failing)
	local done
	local queued, err = ffi_git.branch(dir, function(name, diagnostic)
		assert(not vim.in_fast_event(), 'callback must run on the main loop')
		assert(name == expected, ('expected %q, got %q'):format(expected, name))
		assert((diagnostic ~= nil) == (failing == true), diagnostic)
		done = true
	end)
	assert(queued, err)
	assert(
		vim.wait(5000, function()
			return done
		end),
		'branch callback timed out'
	)
end
local ok, err = xpcall(function()
	local repo = temp .. '/repo'
	local outside = temp .. '/outside'
	vim.fn.mkdir(repo, 'p')
	vim.fn.mkdir(outside, 'p')
	git(repo, 'init', '-b', 'native-test')
	branch(repo, '', true)
	branch(outside, '', true)
	git(repo, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '--allow-empty', '-m', 'initial')
	branch(repo, 'native-test')
	vim.fn.mkdir(repo .. '/nested/deep', 'p')
	branch(repo .. '/nested/deep', 'native-test')
	git(repo, 'checkout', '-b', 'feature/你好')
	branch(repo, 'feature/你好')
	local long_branch = ('segment/'):rep(40) .. 'end'
	git(repo, 'checkout', '-b', long_branch)
	branch(repo, long_branch)
	git(repo, 'worktree', 'add', '-b', 'linked-test', temp .. '/linked')
	branch(temp .. '/linked', 'linked-test')
	git(repo, 'checkout', '--detach')
	git(repo, 'config', 'core.abbrev', '7')
	local short = git(repo, 'rev-parse', '--short=7', 'HEAD')
	branch(repo, short)
	git(repo, 'config', 'core.abbrev', '12')
	short = git(repo, 'rev-parse', '--short', 'HEAD')
	branch(repo, short)
	local completed = 0
	for _ = 1, 16 do
		assert(ffi_git.branch(repo, function(name, diagnostic)
			assert(name == short and not diagnostic)
			completed = completed + 1
		end))
	end
	assert(
		vim.wait(5000, function()
			return completed == 16
		end),
		'concurrent callbacks timed out'
	)
	local lib, load_error = loader.load()
	assert(lib, load_error)
	local small = ffi.new('char[1]', 42)
	assert(lib.ffi_git_branch(repo, small, 1) == -2)
	assert(small[0] == 42, 'insufficient capacity wrote output')
	assert(lib.ffi_git_branch(repo, small, 0) == -2)
	assert(lib.ffi_git_branch(nil, small, 1) == -1)
	assert(lib.ffi_git_branch(repo, nil, 1) == -1)
	local exact = ffi.new('char[?]', #short + 1)
	assert(lib.ffi_git_branch(repo, exact, #short + 1) == #short)
	assert(ffi.string(exact) == short and exact[#short] == 0)
	assert(not pcall(ffi_git.branch, repo .. '\0ignored', function() end))
	assert(not pcall(ffi_git.branch, repo, false))
	-- Reload only the Lua modules to test cached load failure without unloading a library.
	local saved_path = vim.env.NVIM_NATIVE_LIBRARY
	vim.env.NVIM_NATIVE_LIBRARY = temp .. '/missing-library'
	package.loaded['ffi.git'], package.loaded['ffi.loader'] = nil, nil
	local imported, diagnostic = pcall(require, 'ffi.git')
	assert(not imported and diagnostic:find('cargo build --release', 1, true))
	local missing_loader = require 'ffi.loader'
	local missing, cached = missing_loader.load()
	assert(not missing and diagnostic:find(cached, 1, true))
	vim.env.NVIM_NATIVE_LIBRARY = saved_path
end, debug.traceback)
vim.fn.delete(temp, 'rf')
if not ok then
	io.stderr:write(err .. '\n')
	vim.cmd 'cquit'
end
print 'PASS: Rust ABI, ffi.git workers, Git fixtures, concurrency, and missing library'
vim.cmd 'qa!'
