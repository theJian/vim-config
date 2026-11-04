-- Exercise attachment-driven reference highlights with native requests and extmarks.
-- Run with: nvim --headless -u NONE -i NONE -l tests/lsp.lua
-- Only package loading, server activation, and client transport are replaced.
package.path = vim.fn.getcwd() .. '/lua/?.lua;' .. package.path

local highlight_method = vim.lsp.protocol.Methods.textDocument_documentHighlight
local native_handler = vim.lsp.handlers[highlight_method]
local pack_add, enable = vim.pack.add, vim.lsp.enable
vim.pack.add = function() end
vim.lsp.enable = function() end
dofile(vim.fn.getcwd() .. '/after/plugin/lsp.lua')
vim.pack.add, vim.lsp.enable = pack_add, enable
assert(vim.lsp.handlers[highlight_method] == native_handler, 'must preserve the global highlight handler')

local failures = {}
local get_clients, get_client_by_id = vim.lsp.get_clients, vim.lsp.get_client_by_id

local function test(name, callback)
	local original_buf = vim.api.nvim_get_current_buf()
	local original_win = vim.api.nvim_get_current_win()
	local bufnr = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '😀 alpha beta' })
	vim.api.nvim_win_set_cursor(0, { 1, 5 })
	local requests = {}
	local clients = {}
	local function add_client(id, encoding, supported)
		local client = {
			id = id,
			attached = true,
			offset_encoding = encoding,
			supports_method = function(_, method)
				return supported ~= false and method == highlight_method
			end,
			request = function(_, method, params, handler, request_buf)
				assert(method == highlight_method and request_buf == bufnr)
				requests[#requests + 1] = {
					params = params,
					handler = handler,
					ctx = { client_id = id, bufnr = bufnr, method = method },
				}
				return true, #requests
			end,
		}
		clients[#clients + 1] = client
		return client
	end
	add_client(1, 'utf-16')
	vim.lsp.get_clients = function(filter)
		assert(filter.bufnr == bufnr)
		return vim.tbl_filter(function(client)
			return client.attached
				and (not filter.id or filter.id == client.id)
				and (not filter.method or client:supports_method(filter.method))
		end, clients)
	end
	vim.lsp.get_client_by_id = function(id)
		for _, client in ipairs(clients) do
			if client.id == id then
				return client
			end
		end
	end
	local function event(name)
		vim.api.nvim_exec_autocmds(name, { buffer = bufnr, modeline = false })
	end
	local function attach(id)
		vim.api.nvim_exec_autocmds('LspAttach', { buffer = bufnr, data = { client_id = id or 1 } })
	end
	local function marks()
		local ns = vim.api.nvim_get_namespaces()['nvim.lsp.references']
		return ns and vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true }) or {}
	end
	local function respond(index, err, result)
		local request = assert(requests[index], 'missing request')
		request.handler(err, result or {
			{ range = { start = { line = 0, character = 3 }, ['end'] = { line = 0, character = 8 } }, kind = 2 },
		}, request.ctx)
	end
	attach()
	local ok, err = xpcall(function()
		callback {
			bufnr = bufnr,
			requests = requests,
			clients = clients,
			add_client = add_client,
			attach = attach,
			event = event,
			marks = marks,
			respond = respond,
		}
	end, debug.traceback)
	vim.lsp.get_clients, vim.lsp.get_client_by_id = get_clients, get_client_by_id
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if win ~= original_win then
			vim.api.nvim_win_close(win, true)
		end
	end
	vim.api.nvim_set_current_win(original_win)
	vim.api.nvim_set_current_buf(original_buf)
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end
	if ok then
		vim.api.nvim_out_write('PASS: ' .. name .. '\n')
	else
		failures[#failures + 1] = name .. ': ' .. err
		vim.api.nvim_err_writeln('FAIL: ' .. name .. ': ' .. err)
	end
end

test('renders native extmarks using each client encoding and installs callbacks once', function(t)
	t.attach()
	t.add_client(2, 'utf-8')
	t.attach(2)
	t.event 'CursorHold'
	assert(#t.requests == 2, 'one idle callback must request each client once')
	assert(t.requests[1].params.position.character == 3)
	assert(t.requests[2].params.position.character == 5)
	t.respond(1)
	local mark = t.marks()[1]
	assert(mark[3] == 5 and mark[4].end_col == 10 and mark[4].hl_group == 'LspReferenceRead')
	t.event 'CursorMoved'
	t.respond(2)
	assert(#t.marks() == 0, 'cleared request must stay stale')
	t.event 'CursorHold'
	t.respond(4, nil, {
		{ range = { start = { line = 0, character = 5 }, ['end'] = { line = 0, character = 10 } } },
	})
	mark = t.marks()[1]
	assert(mark[3] == 5 and mark[4].end_col == 10, 'response must use the responding client encoding')
end)

test('discards out-of-order responses without erasing the newest highlights', function(t)
	t.event 'CursorHold'
	t.event 'CursorHold'
	t.respond(2)
	local newest = t.marks()
	assert(#newest == 1)
	t.respond(1)
	assert(vim.deep_equal(t.marks(), newest), 'old response must neither append nor clear extmarks')
end)

test('clears and invalidates on every context event even after returning', function(t)
	for _, event in ipairs { 'CursorMoved', 'ModeChanged', 'BufLeave', 'WinLeave', 'TextChanged', 'TextChangedI' } do
		t.event 'CursorHold'
		t.respond(#t.requests)
		assert(#t.marks() == 1)
		t.event 'CursorHold'
		local pending = #t.requests
		t.event(event)
		assert(#t.marks() == 0, event .. ' must clear existing marks')
		t.respond(pending)
		assert(#t.marks() == 0, event .. ' must invalidate pending responses')
	end
	t.event 'CursorHold'
	local pending = #t.requests
	vim.api.nvim_win_set_cursor(0, { 1, 6 })
	t.event 'CursorMoved'
	vim.api.nvim_win_set_cursor(0, { 1, 5 })
	t.respond(pending)
	assert(#t.marks() == 0, 'moving away and back must invalidate the response')
end)

test('rejects requests and responses in actual insert and visual modes', function(t)
	for _, mode in ipairs { { 'i', 'i' }, { 'x', 'v' } } do
		t.event 'CursorHold'
		t.respond(#t.requests)
		t.event 'CursorHold'
		local pending = #t.requests
		local checked = false
		vim.keymap.set(mode[1], '<F6>', function()
			assert(vim.api.nvim_get_mode().mode == mode[2])
			assert(#t.marks() == 0, 'ModeChanged must clear highlights')
			t.respond(pending)
			assert(#t.marks() == 0, 'non-normal response must not render')
			t.event 'CursorHold'
			t.event 'CursorHoldI'
			assert(#t.requests == pending, 'non-normal idle must not request highlights')
			checked = true
		end, { buffer = t.bufnr })
		vim.fn.feedkeys(mode[2] .. vim.keycode '<F6><Esc>', 'xt')
		vim.keymap.del(mode[1], '<F6>', { buffer = t.bufnr })
		assert(checked and vim.api.nvim_get_mode().mode == 'n')
		t.respond(pending)
		assert(#t.marks() == 0, 'returning to normal mode must not revive old responses')
	end
end)

test('rejects changed cursor, text, buffer, window, and destroyed buffers', function(t)
	t.event 'CursorHold'
	vim.api.nvim_win_set_cursor(0, { 1, 6 })
	t.respond(1)
	assert(#t.marks() == 0)
	t.event 'CursorHold'
	vim.api.nvim_buf_set_lines(t.bufnr, 0, -1, false, { '😀 alpha beta!' })
	t.respond(2)
	assert(#t.marks() == 0)
	t.event 'CursorHold'
	local other = vim.api.nvim_create_buf(false, true)
	vim.cmd('noautocmd hide buffer ' .. other)
	t.respond(3)
	assert(#t.marks() == 0)
	vim.cmd('noautocmd hide buffer ' .. t.bufnr)
	vim.api.nvim_buf_delete(other, { force = true })
	t.event 'CursorHold'
	vim.cmd 'noautocmd split'
	t.respond(4)
	assert(#t.marks() == 0, 'another window showing the same buffer is a different context')
	vim.cmd.close()
	t.event 'CursorHold'
	vim.api.nvim_buf_delete(t.bufnr, { force = true })
	t.respond(5)
end)

test('ignores failed, missing, empty, and detached-client responses', function(t)
	t.event 'CursorHold'
	t.respond(1, { code = -32603, message = 'failed' })
	assert(#t.marks() == 0)
	local request = t.requests[1]
	request.handler(nil, nil, request.ctx)
	t.respond(1, nil, {})
	assert(#t.marks() == 0)
	t.clients[1].attached = false
	t.respond(1)
	assert(#t.marks() == 0, 'a detached client may still be alive')
	t.add_client(2, 'utf-16', false)
	t.event 'CursorHold'
	assert(#t.requests == 1, 'must not request when only unsupported clients remain')
	t.clients[1] = nil
	t.respond(1)
	assert(#t.marks() == 0)
end)

if #failures > 0 then
	error(table.concat(failures, '\n'))
end
