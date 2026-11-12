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
local function status(dir, expected)
	local done, result
	local queued, err = ffi_git.status(dir, function(value, diagnostic)
		assert(not vim.in_fast_event(), 'status callback must run on the main loop')
		if expected then
			assert(not diagnostic, diagnostic)
			assert(vim.deep_equal(value, expected), vim.inspect { expected = expected, actual = value })
		else
			assert(value == nil and diagnostic, 'failed status must return nil and a diagnostic')
		end
		result, done = value, true
	end)
	assert(queued, err)
	assert(
		vim.wait(5000, function()
			return done
		end),
		'status callback timed out'
	)
	return result
end
local function expected_status(name, tracked, untracked, ahead, behind, conflicts)
	return {
		branch = name,
		tracked = tracked or 0,
		untracked = untracked or 0,
		ahead = ahead or 0,
		behind = behind or 0,
		conflicts = conflicts or 0,
	}
end
local ok, err = xpcall(function()
	local repo = temp .. '/repo'
	local outside = temp .. '/outside'
	vim.fn.mkdir(repo, 'p')
	vim.fn.mkdir(outside, 'p')
	git(repo, 'init', '-b', 'native-test')
	branch(repo, '', true)
	status(repo, expected_status 'native-test')
	branch(outside, '', true)
	status(outside)
	git(repo, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '--allow-empty', '-m', 'initial')
	branch(repo, 'native-test')
	vim.fn.mkdir(repo .. '/nested/deep', 'p')
	branch(repo .. '/nested/deep', 'native-test')
	status(repo .. '/nested/deep', expected_status 'native-test')
	git(repo, 'checkout', '-b', 'feature/你好')
	branch(repo, 'feature/你好')
	status(repo, expected_status 'feature/你好')
	local long_branch = ('segment/'):rep(40) .. 'end'
	git(repo, 'checkout', '-b', long_branch)
	branch(repo, long_branch)
	status(repo, expected_status(long_branch))
	git(repo, 'worktree', 'add', '-b', 'linked-test', temp .. '/linked')
	branch(temp .. '/linked', 'linked-test')
	status(temp .. '/linked', expected_status 'linked-test')
	git(repo, 'checkout', '--detach')
	git(repo, 'config', 'core.abbrev', '7')
	local short = git(repo, 'rev-parse', '--short=7', 'HEAD')
	branch(repo, short)
	status(repo, expected_status(short))
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
	local counts = ffi.new 'FfiGitCounts[1]'
	counts[0].tracked = 42
	assert(lib.ffi_git_status(repo, small, 1, counts) == -2)
	assert(small[0] == 42 and counts[0].tracked == 42, 'small buffer wrote status output')
	assert(lib.ffi_git_status(repo, small, 0, counts) == -2)
	assert(lib.ffi_git_status(nil, small, 1, counts) == -1)
	assert(lib.ffi_git_status(repo, nil, 1, counts) == -1)
	assert(lib.ffi_git_status(repo, small, 1, nil) == -1)
	assert(lib.ffi_git_status(outside, small, 1, counts) == -1)
	assert(small[0] == 42 and counts[0].tracked == 42, 'failed lookup wrote status output')
	assert(lib.ffi_git_status(repo, exact, #short + 1, counts) == #short)
	assert(ffi.string(exact) == short and exact[#short] == 0 and counts[0].tracked == 0)
	assert(not pcall(ffi_git.branch, repo .. '\0ignored', function() end))
	assert(not pcall(ffi_git.branch, repo, false))
	assert(not pcall(ffi_git.status, repo .. '\0ignored', function() end))
	assert(not pcall(ffi_git.status, repo, false))
	-- File counts cover the entire worktree, with staged/unstaged files counted once.
	local changes = temp .. '/changes'
	vim.fn.mkdir(changes, 'p')
	git(changes, 'init', '-b', 'changes')
	git(changes, 'config', 'user.name', 'Test')
	git(changes, 'config', 'user.email', 'test@example.com')
	vim.fn.writefile({ '*.ignored' }, changes .. '/.gitignore')
	vim.fn.writefile({ 'base' }, changes .. '/modified.txt')
	vim.fn.writefile({ 'delete' }, changes .. '/deleted.txt')
	vim.fn.writefile({ 'rename' }, changes .. '/renamed.txt')
	git(changes, 'add', '.')
	git(changes, 'commit', '-m', 'base')
	status(changes, expected_status 'changes')
	vim.fn.writefile({ 'staged' }, changes .. '/modified.txt')
	vim.fn.writefile({ 'added' }, changes .. '/added.txt')
	git(changes, 'add', '.')
	vim.fn.writefile({ 'staged and unstaged' }, changes .. '/modified.txt')
	vim.fn.delete(changes .. '/deleted.txt')
	git(changes, 'mv', 'renamed.txt', 'new-name.txt')
	vim.fn.mkdir(changes .. '/new/nested', 'p')
	vim.fn.writefile({ 'a' }, changes .. '/new/a.txt')
	vim.fn.writefile({ 'b' }, changes .. '/new/nested/b.txt')
	vim.fn.writefile({ 'ignored' }, changes .. '/new/c.ignored')
	status(changes .. '/new/nested', expected_status('changes', 4, 2))
	git(changes, 'add', '.')
	status(changes, expected_status('changes', 6))
	git(changes, 'commit', '-m', 'all changes')
	status(changes, expected_status 'changes')
	git(changes, 'rm', 'added.txt')
	vim.fn.writefile({ 'recreated after staged deletion' }, changes .. '/added.txt')
	status(changes, expected_status('changes', 1))
	git(changes, 'reset', '--hard', 'HEAD')
	-- Local branches make deterministic upstream fixtures without any network access.
	git(changes, 'branch', 'upstream')
	git(changes, 'branch', '--set-upstream-to=upstream')
	status(changes, expected_status 'changes')
	vim.fn.writefile({ 'local' }, changes .. '/modified.txt')
	git(changes, 'commit', '-am', 'local change')
	status(changes, expected_status('changes', 0, 0, 1))
	git(changes, 'checkout', 'upstream')
	vim.fn.writefile({ 'upstream' }, changes .. '/modified.txt')
	git(changes, 'commit', '-am', 'upstream change')
	git(changes, 'checkout', 'changes')
	status(changes, expected_status('changes', 0, 0, 1, 1))
	local merge = vim.system({ 'git', '-C', changes, 'merge', 'upstream' }, { text = true }):wait()
	assert(merge.code == 1, merge.stderr)
	status(changes, expected_status('changes', 0, 0, 1, 1, 1))
	git(changes, 'merge', '--abort')
	git(changes, 'reset', '--hard', 'upstream~1')
	status(changes, expected_status('changes', 0, 0, 0, 1))
	git(changes, 'branch', '--unset-upstream')
	status(changes, expected_status 'changes')
	completed = 0
	for _ = 1, 16 do
		assert(ffi_git.status(changes, function(value, diagnostic)
			assert(not diagnostic and vim.deep_equal(value, expected_status 'changes'))
			completed = completed + 1
		end))
	end
	assert(
		vim.wait(5000, function()
			return completed == 16
		end),
		'concurrent status callbacks timed out'
	)
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
