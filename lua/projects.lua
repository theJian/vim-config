local M = {}
local api, uv, store = vim.api, vim.uv, require 'workspace_store'
local known, cache, recent, scratch, last = {}, {}, {}, {}, {}
local commands = {}
local function edit(path)
	local buf = vim.fn.bufadd(path)
	vim.fn.bufload(buf)
	vim.bo[buf].buflisted = true
	api.nvim_set_current_buf(buf)
end
local markers = {
	'.git',
	'.hg',
	'.svn',
	'.projectile',
	'.nvim-project.json',
	'Cargo.toml',
	'package.json',
	'go.mod',
	'CMakeLists.txt',
	'Makefile',
	'pyproject.toml',
}
local registry_valid = true
local function detect_root(path)
	return vim.fs.root(path, { '.projectile', '.nvim-project.json' })
		or vim.fs.root(path, { '.git', '.hg', '.svn' })
		or vim.fs.root(path, markers)
end

function M.normalize(path)
	path = vim.fs.normalize(vim.fn.fnamemodify(vim.fs.normalize(path), ':p')):gsub('/+$', '')
	return uv.fs_realpath(path) or (path == '' and '/' or path)
end

function M.contains(root, path)
	return path == root or path:sub(1, #root + 1) == root .. '/' or root == '/'
end

function M.root(path)
	if not path then
		local state = require('workspaces').current()
		if vim.b.project_root then
			return vim.b.project_root
		end
		path = vim.bo.buftype == '' and api.nvim_buf_get_name(0) or vim.fn.getcwd()
		if (path == '' or vim.bo.buftype ~= '') and state.project then
			return state.project
		end
	end
	if path == '' then
		path = vim.fn.getcwd()
	end
	path = M.normalize(path)
	local stat = uv.fs_stat(path)
	local dir = stat and stat.type == 'directory' and path or vim.fs.dirname(path)
	local found = detect_root(dir)
	if found then
		return M.normalize(found)
	end
	local best
	for root in pairs(known) do
		if M.contains(root, dir) and (not best or #root > #best) then
			best = root
		end
	end
	return best or dir
end

local function persist()
	if not registry_valid then
		return
	end -- Keep the damaged registry available for recovery.
	store.write('projects', { known = known, recent = recent })
end

function M.add(path)
	local root = M.normalize(path)
	assert(vim.fn.isdirectory(root) == 1, 'Project directory does not exist: ' .. root)
	known[root] = true
	persist()
	return root
end

function M.list()
	local result = vim.tbl_keys(known)
	table.sort(result)
	return result
end

function M.remove(root)
	known[root], cache[root] = nil, nil
	persist()
end

local function choose(callback)
	store.pick('Projects', M.list(), function(root)
		return vim.fs.basename(root) .. '  ' .. vim.fn.fnamemodify(root, ':~')
	end, callback)
end

function M.switch(root, action, skip_files)
	root = M.add(root)
	require('workspaces').project(root)
	if action then
		action(root)
	elseif not skip_files then
		M.find(root)
	end
end

local function walk(root, callback, done, cancelled)
	local pending, files = { root }, {}
	local function step()
		if cancelled and cancelled() then
			return
		end
		local count = 0
		while #pending > 0 and count < 40 do
			local dir = table.remove(pending)
			local scan = uv.fs_scandir(dir)
			if scan then
				while true do
					local name, kind = uv.fs_scandir_next(scan)
					if not name then
						break
					end
					local path = dir .. '/' .. name
					if kind == 'directory' and name ~= '.git' and name ~= '.hg' and name ~= '.svn' then
						pending[#pending + 1] = path
					elseif not callback and (kind == 'file' or (kind == 'link' and vim.fn.filereadable(path) == 1)) then
						files[#files + 1] = path
					end
				end
			end
			if callback then
				callback(dir)
			end
			count = count + 1
		end
		if #pending == 0 then
			done(files)
		else
			vim.schedule(step)
		end
	end
	vim.schedule(step)
end

function M.files(root, callback)
	if cache[root] then
		callback(cache[root])
		return function() end
	end
	local cancelled, process = false, nil
	local function finish(files)
		if cancelled then
			return
		end
		table.sort(files)
		cache[root] = files
		callback(files)
	end
	local function fallback()
		walk(root, nil, finish, function()
			return cancelled
		end)
	end
	if vim.fn.executable 'git' == 1 then
		process = vim.system(
			{ 'git', '-C', root, 'ls-files', '--cached', '--others', '--exclude-standard', '-z' },
			{},
			function(result)
				vim.schedule(function()
					if cancelled then
						return
					end
					if result.code ~= 0 then
						fallback()
						return
					end
					local files, seen = {}, {}
					for path in result.stdout:gmatch '([^%z]+)%z' do
						local full = root .. '/' .. path
						if not seen[full] and vim.fn.filereadable(full) == 1 then
							files[#files + 1], seen[full] = full, true
						end
					end
					finish(files)
				end)
			end
		)
	else
		fallback()
	end
	return function()
		cancelled = true
		if process then
			pcall(process.kill, process, 15)
		end
	end
end

local function file_picker(root, prompt, source)
	return require('better_select').open {
		prompt = prompt,
		live = false,
		source = source or function(_, emit)
			return M.files(root, emit)
		end,
		format_item = function(path)
			return M.contains(root, path) and path:sub(#root + 2) or path
		end,
		preview_item = function(path)
			return { buf = vim.fn.bufadd(path) }
		end,
		on_choice = function(path)
			edit(path)
		end,
		to_quickfix = function(path)
			return { filename = path, lnum = 1 }
		end,
	}
end

function M.find(root)
	root = root or M.root()
	return file_picker(root, 'Project files')
end

function M.browse(root, directory)
	root, directory = root or M.root(), directory or root or M.root()
	local entries = {}
	if directory ~= root then
		entries[1] = { path = vim.fs.dirname(directory), label = '../', directory = true }
	end
	local children = {}
	for name, kind in vim.fs.dir(directory) do
		if kind == 'link' then
			kind = (uv.fs_stat(directory .. '/' .. name) or {}).type
		end
		children[#children + 1] = {
			path = directory .. '/' .. name,
			label = name .. (kind == 'directory' and '/' or ''),
			directory = kind == 'directory',
		}
	end
	table.sort(children, function(a, b)
		if a.directory ~= b.directory then
			return a.directory
		end
		return a.label < b.label
	end)
	vim.list_extend(entries, children)
	return store.pick('Browse ' .. vim.fn.fnamemodify(directory, ':~'), entries, function(entry)
		return entry.label
	end, function(entry)
		if entry.directory then
			M.browse(root, entry.path)
		else
			edit(entry.path)
		end
	end)
end

function M.discover(path, callback)
	local found = {}
	walk(M.normalize(path), function(dir)
		for _, marker in ipairs(markers) do
			if uv.fs_stat(dir .. '/' .. marker) then
				known[dir], found[#found + 1] = true, dir
				break
			end
		end
	end, function()
		persist()
		vim.notify(('Discovered %d projects'):format(#found))
		if callback then
			callback(found)
		end
	end)
end

function M.buffers(root)
	root = root or M.root()
	return vim.tbl_filter(function(buf)
		local name = api.nvim_buf_get_name(buf)
		return vim.bo[buf].buflisted
			and (
				(name ~= '' and vim.bo[buf].buftype == '' and M.contains(root, M.normalize(name)))
				or scratch[root] == buf
				or vim.b[buf].project_root == root
			)
	end, api.nvim_list_bufs())
end

function M.save(root)
	for _, buf in ipairs(M.buffers(root)) do
		if vim.bo[buf].modified and vim.bo[buf].buftype == '' and api.nvim_buf_get_name(buf) ~= '' then
			api.nvim_buf_call(buf, function()
				vim.cmd.update()
			end)
		end
	end
end

function M.kill(root)
	local buffers = M.buffers(root)
	for _, buf in ipairs(buffers) do
		if vim.bo[buf].modified then
			vim.notify('Save or discard project changes before killing buffers', vim.log.levels.WARN)
			return false
		end
	end
	for _, buf in ipairs(buffers) do
		api.nvim_buf_delete(buf, { force = true })
	end
	return true
end

function M.config(root)
	local path = root .. '/.nvim-project.json'
	if vim.fn.filereadable(path) == 0 then
		return {}
	end
	local value = vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
	assert(
		type(value) == 'table' and (next(value) == nil or not vim.islist(value)),
		'Project configuration must be a JSON object'
	)
	assert(value.options == nil or type(value.options) == 'table', 'Project options must be an object')
	return value
end

function M.edit_config()
	local path = M.root() .. '/.nvim-project.json'
	edit(path)
	if
		vim.fn.filereadable(path) == 0
		and not vim.bo.modified
		and api.nvim_buf_line_count(0) == 1
		and api.nvim_get_current_line() == ''
	then
		api.nvim_buf_set_lines(0, 0, -1, false, {
			'{',
			'  "configure": "",',
			'  "compile": "",',
			'  "run": "",',
			'  "test": "",',
			'  "options": {}',
			'}',
		})
	end
end

local function default_command(root, kind)
	local options = M.config(root)
	if type(options[kind]) == 'string' and options[kind] ~= '' then
		return options[kind]
	end
	local has = function(name)
		return uv.fs_stat(root .. '/' .. name) ~= nil
	end
	if has 'Cargo.toml' then
		return ({ compile = 'cargo build', run = 'cargo run', test = 'cargo test' })[kind]
	end
	if has 'package.json' then
		return ({ compile = 'npm run build', run = 'npm start', test = 'npm test' })[kind]
	end
	if has 'CMakeLists.txt' then
		return ({ configure = 'cmake -S . -B build', compile = 'cmake --build build', test = 'ctest --test-dir build' })[kind]
	end
	if has 'Makefile' then
		return ({ compile = 'make', test = 'make test', run = 'make run' })[kind]
	end
	if has 'go.mod' then
		return ({ compile = 'go build ./...', test = 'go test ./...', run = 'go run .' })[kind]
	end
	return ''
end

function M.execute(root, command, mode)
	last[root] = { command = command, mode = mode }
	local origin, origin_win = api.nvim_get_current_tabpage(), api.nvim_get_current_win()
	if mode == 'terminal' then
		vim.cmd 'botright split'
		vim.cmd.enew()
		vim.b.project_root = root
		vim.fn.jobstart({ vim.o.shell, vim.o.shellcmdflag, command }, { cwd = root, term = true })
		vim.cmd.startinsert()
		return
	end
	local errorformat = vim.o.errorformat
	local function show(result)
		local function publish()
			local lines = vim.split((result.stdout or '') .. (result.stderr or ''), '\n', { trimempty = true })
			local cwd, scope = vim.fn.getcwd(), vim.fn.haslocaldir()
			-- A temporary window gives the parser a local cwd without changing the user's scope.
			local buf = api.nvim_create_buf(false, true)
			local win = api.nvim_open_win(
				buf,
				false,
				{ relative = 'editor', row = 0, col = 0, width = 1, height = 1, hide = true, noautocmd = true }
			)
			local ok, err = pcall(api.nvim_win_call, win, function()
				vim.cmd.lcd(vim.fn.fnameescape(root))
				vim.fn.setqflist(
					{},
					' ',
					{ title = command .. ' [exit ' .. result.code .. ']', lines = lines, efm = errorformat }
				)
			end)
			api.nvim_win_close(win, true)
			api.nvim_buf_delete(buf, { force = true })
			-- win_call restores the window, but may leave the process cwd at the parser's cwd.
			api.nvim_cmd({
				cmd = scope == 1 and 'lcd' or scope == 2 and 'tcd' or 'cd',
				args = { cwd },
				mods = { noautocmd = true },
			}, {})
			if not ok then
				error(err)
			end
			if
				api.nvim_get_current_tabpage() == origin
				and api.nvim_get_current_win() == origin_win
				and api.nvim_get_mode().mode == 'n'
			then
				vim.cmd.copen()
			end
			vim.notify(
				('Project command exited %d'):format(result.code),
				result.code == 0 and vim.log.levels.INFO or vim.log.levels.WARN
			)
		end
		vim._with({ noautocmd = true }, publish)
	end
	if mode == 'sync' then
		show(vim.system({ vim.o.shell, vim.o.shellcmdflag, command }, { cwd = root, text = true }):wait())
	else
		return vim.system({ vim.o.shell, vim.o.shellcmdflag, command }, { cwd = root, text = true }, function(result)
			vim.schedule(function()
				show(result)
			end)
		end)
	end
end

function M.command(kind)
	local root = M.root()
	if kind == 'repeat' then
		if last[root] then
			local previous = last[root]
			local function repeat_command(command)
				M.save(root)
				M.execute(root, command, previous.mode)
			end
			if vim.v.count > 0 then
				store.input('Repeat project command', previous.command, repeat_command)
			else
				repeat_command(previous.command)
			end
		else
			vim.notify 'No previous project command'
		end
		return
	end
	local default = commands[root] and commands[root][kind] or default_command(root, kind)
	store.input(kind .. ' in ' .. vim.fs.basename(root), default, function(command)
		commands[root] = commands[root] or {}
		commands[root][kind] = command
		if kind ~= 'shell' and kind ~= 'async' then
			M.save(root)
		end
		M.execute(root, command, kind == 'shell' and 'sync' or kind == 'run' and 'terminal' or 'async')
	end)
end

function M.scratch(toggle)
	local root = M.root()
	local buf = scratch[root]
	for _, candidate in ipairs(require('workspaces').buffers()) do
		if vim.b[candidate].project_scratch and vim.b[candidate].project_root == root then
			buf, scratch[root] = candidate, candidate
			break
		end
	end
	if not buf or not api.nvim_buf_is_valid(buf) then
		for _, candidate in ipairs(api.nvim_list_bufs()) do
			if vim.b[candidate].project_scratch and vim.b[candidate].project_root == root then
				buf, scratch[root] = candidate, candidate
				break
			end
		end
	end
	if buf and api.nvim_buf_is_valid(buf) and toggle then
		for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
			if api.nvim_win_get_buf(win) == buf then
				local normal = vim.tbl_filter(function(w)
					return api.nvim_win_get_config(w).relative == ''
				end, api.nvim_tabpage_list_wins(0))
				if #normal > 1 then
					api.nvim_win_close(win, false)
				else
					vim.cmd.enew()
				end
				return
			end
		end
	end
	if not buf or not api.nvim_buf_is_valid(buf) then
		buf = api.nvim_create_buf(true, false)
		scratch[root] = buf
		api.nvim_buf_set_name(buf, 'project-scratch://' .. root)
		vim.bo[buf].buftype, vim.bo[buf].bufhidden, vim.bo[buf].swapfile = 'nofile', 'hide', false
		vim.b[buf].project_root = root
		vim.b[buf].project_scratch = true
	end
	if toggle then
		vim.cmd 'botright split'
	end
	api.nvim_set_current_buf(buf)
end

function M.sibling()
	local path, root = api.nvim_buf_get_name(0), M.root()
	local base = vim.fn.fnamemodify(path, ':t:r'):gsub('[._-]test$', ''):gsub('[._-]spec$', ''):gsub('^test[._-]', '')
	file_picker(root, 'Sibling files', function(_, emit)
		return M.files(root, function(files)
			emit(vim.tbl_filter(function(file)
				local name = vim.fn
					.fnamemodify(file, ':t:r')
					:gsub('[._-]test$', '')
					:gsub('[._-]spec$', '')
					:gsub('^test[._-]', '')
				return file ~= path and (name == base or vim.fs.dirname(file) == vim.fs.dirname(path))
			end, files))
		end)
	end)
end

function M.setup()
	local ok, saved = pcall(store.read, 'projects')
	registry_valid = ok
		and (
			saved == nil
			or (type(saved.known) == 'table' and type(saved.recent) == 'table' and vim.islist(saved.recent))
		)
	if registry_valid and saved then
		for root, value in pairs(saved.known) do
			if type(root) ~= 'string' or value ~= true then
				registry_valid = false
			end
		end
		for _, path in ipairs(saved.recent) do
			if type(path) ~= 'string' then
				registry_valid = false
			end
		end
	end
	if not registry_valid then
		vim.notify(
			'Invalid project registry; persistence disabled until ' .. store.directory() .. '/projects.json is repaired',
			vim.log.levels.WARN
		)
		saved = nil
	end
	saved = saved or {}
	known, recent = saved.known or {}, saved.recent or {}
	local group = api.nvim_create_augroup('NativeProjects', { clear = true })
	api.nvim_create_autocmd('BufEnter', {
		group = group,
		callback = function(ev)
			local path = api.nvim_buf_get_name(ev.buf)
			if vim.bo[ev.buf].buftype ~= '' or path == '' then
				return
			end
			path = M.normalize(path)
			recent = vim.tbl_filter(function(item)
				return item ~= path
			end, recent)
			table.insert(recent, 1, path)
			while #recent > 1000 do
				table.remove(recent)
			end
			local root = detect_root(path)
			if root then
				known[M.normalize(root)] = true
			end
			local ok, root_config = pcall(M.config, root or M.root(path))
			if not ok then
				vim.notify(root_config, vim.log.levels.WARN)
				return
			end
			-- Explicitly allow only buffer-local editing preferences; no exrc or arbitrary Lua.
			for _, option in ipairs { 'shiftwidth', 'tabstop', 'softtabstop', 'expandtab', 'textwidth', 'spell' } do
				if root_config.options and root_config.options[option] ~= nil then
					pcall(
						api.nvim_set_option_value,
						option,
						root_config.options[option],
						option == 'spell' and { win = 0 } or { buf = ev.buf }
					)
				end
			end
		end,
	})
	api.nvim_create_autocmd('VimLeavePre', { group = group, callback = persist })
	if M.mappings_initialized then
		return
	end
	M.mappings_initialized = true
	local bindings = {
		['browse'] = {
			'Browse project',
			function()
				M.browse()
			end,
		},
		['browse-other'] = {
			'Browse other project',
			function()
				choose(function(root)
					M.switch(root, M.browse)
				end)
			end,
		},
		['shell'] = {
			'Run command in project root',
			function()
				M.command 'shell'
			end,
		},
		['async'] = {
			'Async command in project root',
			function()
				M.command 'async'
			end,
		},
		['add'] = {
			'Add new project',
			function()
				store.input('Project directory', vim.fn.getcwd(), M.add, 'dir')
			end,
		},
		['buffers'] = {
			'Switch to project buffer',
			function()
				store.pick('Project buffers', M.buffers(), function(buf)
					return api.nvim_buf_get_name(buf)
				end, api.nvim_set_current_buf)
			end,
		},
		['compile'] = {
			'Compile project',
			function()
				M.command 'compile'
			end,
		},
		['repeat'] = {
			'Repeat last project command',
			function()
				M.command 'repeat'
			end,
		},
		['remove'] = {
			'Remove known project',
			function()
				choose(M.remove)
			end,
		},
		['discover'] = {
			'Discover projects in folder',
			function()
				store.input('Discover under', vim.fn.getcwd(), M.discover, 'dir')
			end,
		},
		['edit-config'] = { 'Edit project local configuration', M.edit_config },
		['find'] = {
			'Find file in project',
			function()
				M.find()
			end,
		},
		['find-other'] = {
			'Find file in other project',
			function()
				choose(function(root)
					M.switch(root, M.find)
				end)
			end,
		},
		['configure'] = {
			'Configure project',
			function()
				M.command 'configure'
			end,
		},
		['invalidate'] = {
			'Invalidate project cache',
			function()
				cache[M.root()] = nil
			end,
		},
		['kill'] = {
			'Kill project buffers',
			function()
				M.kill()
			end,
		},
		['sibling'] = { 'Find sibling file', M.sibling },
		['switch'] = {
			'Switch project',
			function()
				local skip = vim.v.count > 0
				choose(function(root)
					M.switch(root, nil, skip)
				end)
			end,
		},
		['recent'] = {
			'Find recent project files',
			function()
				local root, seen, files = M.root(), {}, {}
				for _, path in ipairs(vim.list_extend(vim.deepcopy(recent), vim.v.oldfiles)) do
					if not seen[path] and M.contains(root, path) and vim.fn.filereadable(path) == 1 then
						files[#files + 1], seen[path] = path, true
					end
				end
				file_picker(root, 'Recent project files', files)
			end,
		},
		['run'] = {
			'Run project',
			function()
				M.command 'run'
			end,
		},
		['save'] = {
			'Save project files',
			function()
				M.save()
			end,
		},
		['test'] = {
			'Test project',
			function()
				M.command 'test'
			end,
		},
		['scratch-toggle'] = {
			'Toggle project scratch buffer',
			function()
				M.scratch(true)
			end,
		},
		['scratch'] = {
			'Switch to project scratch buffer',
			function()
				M.scratch(false)
			end,
		},
	}
	for key, item in pairs(bindings) do
		vim.keymap.set('n', '<Plug>(acme-projects-' .. key .. ')', item[2], { desc = item[1], unique = true })
	end
end

return M
