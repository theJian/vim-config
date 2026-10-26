local M = {}
local api, store = vim.api, require 'workspace_store'
local states, previous, entered, suspended = {}, nil, nil, false

local function unique(name, except)
	local used = {}
	for tab, state in pairs(states) do
		if tab ~= except then
			used[state.name] = true
		end
	end
	local base, i = name, 2
	while used[name] do
		name, i = base .. ' (' .. i .. ')', i + 1
	end
	return name
end

function M.current()
	local tab = api.nvim_get_current_tabpage()
	if not states[tab] then
		states[tab] = { name = unique(next(states) and 'workspace' or 'main'), buffers = {}, root = vim.fn.getcwd() }
		vim.t[tab].tabname = states[tab].name
	end
	return states[tab], tab
end

function M.list()
	local list = {}
	for _, tab in ipairs(api.nvim_list_tabpages()) do
		if states[tab] then
			list[#list + 1] = { tab = tab, name = states[tab].name, root = states[tab].root }
		end
	end
	return list
end

function M.track(buf)
	if suspended or not api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted then
		return
	end
	local state = M.current()
	state.buffers[buf] = true
end

function M.buffers()
	local list = {}
	for buf in pairs(M.current().buffers) do
		if api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
			list[#list + 1] = buf
		end
	end
	table.sort(list)
	return list
end

function M.switch(tab)
	assert(api.nvim_tabpage_is_valid(tab), 'Workspace is no longer open')
	api.nvim_set_current_tabpage(tab)
end

function M.new(name, root)
	vim.cmd.tabnew()
	local state, tab = M.current()
	state.name = unique(name or 'workspace', tab)
	vim.t[tab].tabname = state.name
	state.root = root or vim.fn.getcwd()
	vim.cmd.tcd(vim.fn.fnameescape(state.root))
	M.track(api.nvim_get_current_buf())
	return tab
end

function M.project(root)
	for _, item in ipairs(M.list()) do
		if states[item.tab].project == root then
			M.switch(item.tab)
			return item.tab, false
		end
	end
	local tab = M.new(vim.fs.basename(root), root)
	states[tab].project = root
	return tab, true
end

function M.rename(name)
	for tab, state in pairs(states) do
		assert(tab == api.nvim_get_current_tabpage() or state.name ~= name, 'Workspace name already exists')
	end
	M.current().name = name
	vim.t.tabname = name
end

function M.other()
	if previous and api.nvim_tabpage_is_valid(previous) then
		M.switch(previous)
	end
end

function M.cycle(delta)
	local tabs, index = api.nvim_list_tabpages(), api.nvim_tabpage_get_number(0)
	M.switch(tabs[(index - 1 + delta) % #tabs + 1])
end

function M.number(number)
	local tabs = api.nvim_list_tabpages()
	if number == 0 then
		number = #tabs
	end
	if tabs[number] then
		M.switch(tabs[number])
	end
end

local function guarded(buffers)
	for _, buf in ipairs(buffers) do
		if api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
			vim.notify(
				'Save or discard changes first: '
					.. (api.nvim_buf_get_name(buf) ~= '' and api.nvim_buf_get_name(buf) or '[No Name]'),
				vim.log.levels.WARN
			)
			return false
		end
	end
	return true
end

function M.kill(target)
	if target and target ~= api.nvim_get_current_tabpage() then
		local origin = api.nvim_get_current_tabpage()
		M.switch(target)
		local killed = M.kill()
		M.switch(origin)
		return killed
	end
	local state, tab = M.current()
	local fallback = previous
	local exclusive = {}
	for _, buf in ipairs(M.buffers()) do
		local shared = false
		for other, data in pairs(states) do
			if other ~= tab and data.buffers[buf] then
				shared = true
			end
		end
		if not shared then
			exclusive[#exclusive + 1] = buf
		end
	end
	if not guarded(exclusive) then
		return false
	end
	local replacement
	if #api.nvim_list_tabpages() == 1 then
		replacement = M.new('main', state.root)
	end
	M.switch(tab)
	vim.cmd.tabclose()
	states[tab] = nil
	if replacement then
		M.switch(replacement)
		M.rename 'main'
	end
	if fallback and api.nvim_tabpage_is_valid(fallback) then
		M.switch(fallback)
	end
	for _, buf in ipairs(exclusive) do
		if api.nvim_buf_is_valid(buf) then
			api.nvim_buf_delete(buf, { force = true })
		end
	end
	return true
end

function M.clear()
	local buffers = vim.tbl_filter(function(buf)
		return vim.bo[buf].buflisted
	end, api.nvim_list_bufs())
	if not guarded(buffers) then
		return false
	end
	vim.cmd.tabnew()
	vim.cmd.tabonly()
	states = {}
	M.current().name = 'main'
	vim.t.tabname = 'main'
	for _, buf in ipairs(buffers) do
		if api.nvim_buf_is_valid(buf) then
			api.nvim_buf_delete(buf, { force = true })
		end
	end
	M.track(api.nvim_get_current_buf())
	return true
end

local function buffer_data(buf)
	local kind = vim.bo[buf].buftype
	local data = {
		name = api.nvim_buf_get_name(buf),
		kind = kind,
		filetype = vim.bo[buf].filetype,
		project_root = vim.b[buf].project_root,
		project_scratch = vim.b[buf].project_scratch,
	}
	-- Processes cannot be serialized. Keep their output without restarting commands.
	if kind ~= '' or data.name == '' or vim.bo[buf].modified then
		data.lines = api.nvim_buf_get_lines(buf, 0, -1, false)
		data.modified = vim.bo[buf].modified
	end
	return data
end

function M.snapshot(tabs)
	local result, ids = { version = 1, buffers = {}, workspaces = {}, active = 1 }, {}
	local handles = {}
	local current = api.nvim_get_current_tabpage()
	local function id(buf)
		if not ids[buf] then
			result.buffers[#result.buffers + 1] = buffer_data(buf)
			ids[buf] = #result.buffers
			handles[#result.buffers] = buf
		end
		return ids[buf]
	end
	for _, tab in ipairs(tabs or api.nvim_list_tabpages()) do
		local state = states[tab]
		local workspace = {
			name = state.name,
			root = vim.fn.getcwd(-1, api.nvim_tabpage_get_number(tab)),
			project = state.project,
			buffers = {},
		}
		for buf in pairs(state.buffers) do
			if api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
				workspace.buffers[#workspace.buffers + 1] = id(buf)
			end
		end
		local focus = api.nvim_tabpage_get_win(tab)
		local function layout(node)
			if node[1] ~= 'leaf' then
				return { kind = node[1], children = vim.tbl_map(layout, node[2]) }
			end
			local win = node[2]
			return {
				kind = 'leaf',
				buffer = id(api.nvim_win_get_buf(win)),
				focus = win == focus,
				width = api.nvim_win_get_width(win),
				height = api.nvim_win_get_height(win),
				view = api.nvim_win_call(win, vim.fn.winsaveview),
				cwd = vim.fn.haslocaldir(api.nvim_win_get_number(win), api.nvim_tabpage_get_number(tab)) == 1
						and vim.fn.getcwd(api.nvim_win_get_number(win), api.nvim_tabpage_get_number(tab))
					or nil,
			}
		end
		workspace.layout = layout(vim.fn.winlayout(api.nvim_tabpage_get_number(tab)))
		result.workspaces[#result.workspaces + 1] = workspace
		if tab == current then
			result.active = #result.workspaces
		end
	end
	return result, handles
end

local function validate_snapshot(data)
	assert(
		type(data) == 'table'
			and data.version == 1
			and type(data.workspaces) == 'table'
			and vim.islist(data.workspaces)
			and #data.workspaces > 0
			and type(data.buffers) == 'table'
			and vim.islist(data.buffers),
		'Invalid workspace snapshot'
	)
	local function integer(n, minimum)
		return type(n) == 'number' and n == math.floor(n) and n >= minimum and n < math.huge
	end
	assert(integer(data.active, 1) and data.workspaces[data.active], 'Invalid active workspace')
	for _, saved in ipairs(data.buffers) do
		assert(
			type(saved) == 'table'
				and type(saved.name) == 'string'
				and type(saved.kind) == 'string'
				and type(saved.filetype) == 'string',
			'Invalid saved buffer'
		)
		assert(saved.project_root == nil or type(saved.project_root) == 'string', 'Invalid buffer project')
		assert(saved.modified == nil or type(saved.modified) == 'boolean', 'Invalid modified flag')
		if saved.lines then
			assert(type(saved.lines) == 'table' and vim.islist(saved.lines) and #saved.lines > 0, 'Invalid saved text')
			for _, line in ipairs(saved.lines) do
				assert(type(line) == 'string', 'Invalid saved line')
			end
		end
	end
	local function reference(i)
		assert(integer(i, 1) and data.buffers[i], 'Invalid buffer reference')
	end
	local function layout(node, depth)
		assert(type(node) == 'table' and depth < 100, 'Invalid layout')
		if node.kind == 'leaf' then
			reference(node.buffer)
			assert(integer(node.width, 1) and integer(node.height, 1), 'Invalid window size')
			assert(type(node.view) == 'table', 'Invalid window view')
			for _, key in ipairs { 'lnum', 'col', 'coladd', 'curswant', 'topline', 'topfill', 'leftcol', 'skipcol' } do
				assert(integer(node.view[key], (key == 'lnum' or key == 'topline') and 1 or 0), 'Invalid view ' .. key)
			end
			assert(node.cwd == nil or type(node.cwd) == 'string', 'Invalid window directory')
		else
			assert(
				(node.kind == 'row' or node.kind == 'col')
					and type(node.children) == 'table'
					and vim.islist(node.children)
					and #node.children > 0,
				'Invalid split'
			)
			for _, child in ipairs(node.children) do
				layout(child, depth + 1)
			end
		end
	end
	for _, workspace in ipairs(data.workspaces) do
		assert(
			type(workspace) == 'table'
				and type(workspace.name) == 'string'
				and workspace.name:match '%S'
				and type(workspace.root) == 'string'
				and type(workspace.buffers) == 'table'
				and vim.islist(workspace.buffers),
			'Invalid workspace'
		)
		assert(workspace.project == nil or type(workspace.project) == 'string', 'Invalid workspace project')
		layout(workspace.layout, 0)
		for _, i in ipairs(workspace.buffers) do
			reference(i)
		end
	end
end

function M.restore(data, replace, live_buffers)
	validate_snapshot(data)
	if replace then
		for _, buf in ipairs(api.nvim_list_bufs()) do
			if vim.bo[buf].buflisted and vim.bo[buf].modified then
				vim.notify('Save or discard changes before replacing the session', vim.log.levels.WARN)
				return false
			end
		end
	end
	for index, saved in ipairs(data.buffers) do
		local existing = saved.name ~= '' and vim.fn.bufnr(saved.name) or -1
		assert(
			live_buffers or not (saved.lines and existing >= 0 and vim.bo[existing].modified),
			'Cannot overwrite modified buffer: ' .. saved.name
		)
		assert(not live_buffers or api.nvim_buf_is_valid(live_buffers[index]), 'Invalid clone buffer')
	end
	local original_tab, original_win = api.nvim_get_current_tabpage(), api.nvim_get_current_win()
	local original_states, original_previous = vim.deepcopy(states), previous
	local old, before, backups, buffers, created, used = api.nvim_list_tabpages(), {}, {}, {}, {}, {}
	local original_tabs = {}
	for _, tab in ipairs(old) do
		original_tabs[tab] = true
	end
	for _, buf in ipairs(api.nvim_list_bufs()) do
		before[buf] = true
	end
	suspended = true
	local ok, err = pcall(function()
		for i, saved in ipairs(data.buffers) do
			local buf
			if live_buffers then
				buf = live_buffers[i]
			elseif saved.kind == '' and saved.name ~= '' then
				buf = vim.fn.bufadd(saved.name)
				if before[buf] then
					backups[buf] = {
						loaded = api.nvim_buf_is_loaded(buf),
						listed = vim.bo[buf].buflisted,
						filetype = vim.bo[buf].filetype,
						modified = vim.bo[buf].modified,
						modifiable = vim.bo[buf].modifiable,
						vars = {
							project_root = vim.b[buf].project_root,
							project_scratch = vim.b[buf].project_scratch,
							workspace_restore_tick = vim.b[buf].workspace_restore_tick,
						},
					}
					if backups[buf].loaded then
						backups[buf].lines = api.nvim_buf_get_lines(buf, 0, -1, false)
					end
				end
				vim.fn.bufload(buf)
			else
				buf = api.nvim_create_buf(true, false)
				vim.bo[buf].buftype = saved.kind == '' and '' or 'nofile'
				vim.bo[buf].bufhidden = 'hide'
				if saved.project_scratch and vim.fn.bufnr(saved.name) == -1 then
					api.nvim_buf_set_name(buf, saved.name)
				end
			end
			if not live_buffers then
				if saved.lines then
					api.nvim_buf_set_lines(buf, 0, -1, false, saved.lines)
				end
				vim.bo[buf].buflisted = true
				vim.bo[buf].filetype = saved.filetype
				vim.b[buf].project_root, vim.b[buf].project_scratch = saved.project_root, saved.project_scratch
				if saved.lines then
					vim.bo[buf].modified = saved.modified or false
					if saved.modified then
						vim.b[buf].workspace_restore_tick = api.nvim_buf_get_changedtick(buf)
					end
				end
			end
			buffers[i], used[buf] = buf, true
		end
		for _, workspace in ipairs(data.workspaces) do
			local root = vim.fn.isdirectory(workspace.root) == 1 and workspace.root or vim.fn.getcwd()
			local tab = M.new(workspace.name, root)
			created[#created + 1] = tab
			local state = states[tab]
			state.project, state.buffers = workspace.project, {}
			for _, i in ipairs(workspace.buffers) do
				state.buffers[buffers[i]] = true
			end
			local focus, leaves = nil, {}
			local function build(node, win)
				api.nvim_set_current_win(win)
				if node.kind == 'leaf' then
					api.nvim_win_set_buf(win, buffers[node.buffer])
					state.buffers[buffers[node.buffer]] = true
					if node.cwd and vim.fn.isdirectory(node.cwd) == 1 then
						vim.cmd.lcd(vim.fn.fnameescape(node.cwd))
					end
					leaves[#leaves + 1] = { win = win, node = node }
					if node.focus then
						focus = win
					end
					return
				end
				local wins = { win }
				for _ = 2, #node.children do
					vim.cmd(node.kind == 'row' and 'rightbelow vsplit' or 'rightbelow split')
					wins[#wins + 1] = api.nvim_get_current_win()
				end
				for i, child in ipairs(node.children) do
					build(child, wins[i])
				end
			end
			build(workspace.layout, api.nvim_get_current_win())
			for _, leaf in ipairs(leaves) do
				api.nvim_win_set_width(leaf.win, leaf.node.width)
				api.nvim_win_set_height(leaf.win, leaf.node.height)
			end
			-- Splitting and resizing can scroll earlier windows. Restore views last.
			for _, leaf in ipairs(leaves) do
				api.nvim_win_call(leaf.win, function()
					vim.fn.winrestview(leaf.node.view)
				end)
			end
			if focus then
				api.nvim_set_current_win(focus)
			end
		end
	end)
	if not ok then
		vim._with({ noautocmd = true }, function()
			-- Roll back staged tabs and buffer edits; never leave a half-loaded session.
			for _, tab in ipairs(api.nvim_list_tabpages()) do
				if not original_tabs[tab] then
					M.switch(tab)
					vim.cmd 'tabclose!'
				end
			end
			api.nvim_set_current_win(original_win)
			for buf, backup in pairs(backups) do
				vim.bo[buf].modifiable = true
				if backup.lines and not vim.deep_equal(backup.lines, api.nvim_buf_get_lines(buf, 0, -1, false)) then
					api.nvim_buf_set_lines(buf, 0, -1, false, backup.lines)
				end
				vim.bo[buf].filetype, vim.bo[buf].modified = backup.filetype, backup.modified
				vim.bo[buf].buflisted = backup.listed
				vim.bo[buf].modifiable = backup.modifiable
				for _, key in ipairs { 'project_root', 'project_scratch', 'workspace_restore_tick' } do
					vim.b[buf][key] = backup.vars[key]
				end
				if backup.vars.workspace_restore_tick then
					vim.b[buf].workspace_restore_tick = api.nvim_buf_get_changedtick(buf)
				end
				if not backup.loaded then
					api.nvim_buf_delete(buf, { unload = true, force = true })
				end
			end
			for _, buf in ipairs(api.nvim_list_bufs()) do
				if not before[buf] then
					api.nvim_buf_delete(buf, { force = true })
				end
			end
		end)
		states, previous, entered, suspended = original_states, original_previous, original_tab, false
		error(err)
	end
	if replace then
		vim._with({ noautocmd = true }, function()
			for _, tab in ipairs(old) do
				M.switch(tab)
				vim.cmd 'tabclose!'
				states[tab] = nil
			end
			for i, tab in ipairs(created) do
				states[tab].name = data.workspaces[i].name
				vim.t[tab].tabname = states[tab].name
			end
		end)
	end
	M.switch(created[data.active])
	vim._with({ noautocmd = true }, function()
		local obsolete = {}
		if replace then
			for _, state in pairs(original_states) do
				for buf in pairs(state.buffers) do
					obsolete[buf] = true
				end
			end
		end
		for _, buf in ipairs(api.nvim_list_bufs()) do
			if
				not used[buf]
				and not vim.bo[buf].modified
				and (
					obsolete[buf]
					or (not before[buf] and api.nvim_buf_get_name(buf) == '' and vim.bo[buf].buftype == '')
				)
			then
				api.nvim_buf_delete(buf, { force = true })
			end
		end
	end)
	previous, entered, suspended = replace and nil or original_tab, api.nvim_get_current_tabpage(), false
	return true
end

function M.clone(name)
	local data, handles = M.snapshot { api.nvim_get_current_tabpage() }
	data.workspaces[1].name = name or (M.current().name .. ' copy')
	return M.restore(data, false, handles)
end

function M.save(name)
	local saved = store.read 'saved' or {}
	saved[name or M.current().name] = M.snapshot { api.nvim_get_current_tabpage() }
	store.write('saved', saved)
end

function M.load(name)
	local saved = store.read 'saved' or {}
	assert(saved[name], 'No saved workspace: ' .. name)
	return M.restore(saved[name], false)
end

function M.reload()
	if not guarded(M.buffers()) then
		return false
	end
	local name, tab = M.current().name, api.nvim_get_current_tabpage()
	M.load(name)
	local restored = api.nvim_get_current_tabpage()
	M.kill(tab)
	M.switch(restored)
	M.rename(name)
	return true
end

local function choose_saved(callback)
	local names = vim.tbl_keys(store.read 'saved' or {})
	table.sort(names)
	store.pick('Saved workspaces', names, nil, callback)
end

function M.save_session()
	local snapshot = M.snapshot()
	for _, buffer in ipairs(snapshot.buffers) do
		if (buffer.kind == '' and buffer.name ~= '') or (buffer.lines and table.concat(buffer.lines, '') ~= '') then
			store.write('last-session', snapshot)
			return true
		end
	end
	return false
end

function M.setup()
	local group = api.nvim_create_augroup('NativeWorkspaces', { clear = true })
	M.current()
	M.track(api.nvim_get_current_buf())
	entered = api.nvim_get_current_tabpage()
	api.nvim_create_autocmd({ 'TabEnter', 'TabNewEntered' }, {
		group = group,
		callback = function()
			local tab = api.nvim_get_current_tabpage()
			if entered ~= tab then
				previous, entered = entered, tab
			end
			M.current()
		end,
	})
	api.nvim_create_autocmd('TabClosed', {
		group = group,
		callback = function()
			for tab in pairs(states) do
				if not api.nvim_tabpage_is_valid(tab) then
					states[tab] = nil
				end
			end
		end,
	})
	api.nvim_create_autocmd('BufEnter', {
		group = group,
		callback = function(ev)
			M.track(ev.buf)
		end,
	})
	api.nvim_create_autocmd('VimLeavePre', {
		group = group,
		callback = function()
			M.save_session()
		end,
	})
	if M.mappings_initialized then
		return
	end
	M.mappings_initialized = true
	local bindings = {
		['list'] = {
			'Display workspaces',
			function()
				local labels = vim.tbl_map(function(item)
					return ('%d:%s'):format(api.nvim_tabpage_get_number(item.tab), item.name)
				end, M.list())
				vim.api.nvim_echo({ { table.concat(labels, '  ') } }, false, {})
			end,
		},
		['switch'] = {
			'Switch workspace',
			function()
				if vim.v.count > 0 then
					M.number(vim.v.count)
					return
				end
				store.pick('Workspaces', M.list(), function(item)
					return item.name .. '  ' .. item.root
				end, function(item)
					M.switch(item.tab)
				end)
			end,
		},
		['last'] = { 'Switch to last workspace', M.other },
		['new'] = {
			'New workspace',
			function()
				if vim.v.count > 0 then
					M.clone()
				else
					M.new()
				end
			end,
		},
		['new-named'] = {
			'New named workspace',
			function()
				store.input('Workspace name', '', vim.v.count > 0 and M.clone or M.new)
			end,
		},
		['load'] = {
			'Load workspace from file',
			function()
				if vim.v.count > 0 then
					M.reload()
				else
					choose_saved(M.load)
				end
			end,
		},
		['save'] = {
			'Save workspace to file',
			function()
				if vim.v.count > 0 then
					M.save()
				else
					store.input('Save workspace', M.current().name, M.save)
				end
			end,
		},
		['clear'] = { 'Kill session', M.clear },
		['kill'] = {
			'Kill this workspace',
			function()
				if vim.v.count > 0 then
					store.pick('Kill workspace', M.list(), function(item)
						return item.name
					end, function(item)
						M.kill(item.tab)
					end)
				else
					M.kill()
				end
			end,
		},
		['delete-saved'] = {
			'Delete saved workspace',
			function()
				choose_saved(function(name)
					local saved = store.read 'saved'
					saved[name] = nil
					store.write('saved', saved)
				end)
			end,
		},
		['rename'] = {
			'Rename workspace',
			function()
				store.input('Workspace name', M.current().name, M.rename)
			end,
		},
		['restore'] = {
			'Restore last session',
			function()
				local saved = store.read 'last-session'
				if saved then
					M.restore(saved, true)
				else
					vim.notify 'No saved session'
				end
			end,
		},
		['next'] = {
			'Next workspace',
			function()
				M.cycle(vim.v.count1)
			end,
		},
		['previous'] = {
			'Previous workspace',
			function()
				M.cycle(-vim.v.count1)
			end,
		},
	}
	for key, item in pairs(bindings) do
		vim.keymap.set('n', '<Plug>(acme-workspaces-' .. key .. ')', item[2], { desc = item[1], unique = true })
	end
	for i = 0, 9 do
		vim.keymap.set({ 'n', 'i', 't' }, '<Plug>(acme-workspaces-' .. i .. ')', function()
			M.number(i)
		end, { desc = 'Switch workspace ' .. i, unique = true })
	end
	vim.keymap.set('n', '<Plug>(acme-workspaces-create)', function()
		M.new()
	end, { desc = 'New workspace', unique = true })
	local function pick_buffers()
		store.pick('Workspace buffers', M.buffers(), function(buf)
			local name = api.nvim_buf_get_name(buf)
			return name ~= '' and vim.fn.fnamemodify(name, ':~:.') or '[No Name]'
		end, function(buf)
			api.nvim_set_current_buf(buf)
		end)
	end
	vim.keymap.set(
		'n',
		'<Plug>(acme-workspaces-buffers)',
		pick_buffers,
		{ desc = 'Switch workspace buffer', unique = true }
	)
end

return M
