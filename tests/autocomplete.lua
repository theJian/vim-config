-- Run with: nvim --headless -n -u NONE -i NONE -c 'luafile tests/autocomplete.lua'
package.path = vim.fn.getcwd() .. '/lua/?.lua;' .. package.path

local completion = require 'plugins.completion'
local requests = 0
local client = {
	id = 42,
	requests = {},
	offset_encoding = 'utf-16',
	server_capabilities = { completionProvider = { triggerCharacters = { '.' } } },
	supports_method = function(_, method)
		return method == 'textDocument/completion'
	end,
	request = function(_, _, _, callback)
		requests = requests + 1
		vim.defer_fn(function()
			callback(nil, { { label = 'applelsp' } })
		end, 30)
		return true, requests
	end,
	cancel_request = function() end,
}

local function check(callback)
	local ok, err = pcall(callback)
	if not ok then
		vim.api.nvim_err_writeln('FAIL: autocomplete integration: ' .. err)
		vim.cmd.cquit()
	end
end

local function type_prefix()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'applebuffer', '' })
	vim.api.nvim_win_set_cursor(0, { 2, 0 })
	vim.api.nvim_input 'iapp'
end

vim.schedule(type_prefix)
vim.defer_fn(function()
	check(function()
		local items = vim.fn.complete_info().items
		assert(#items == 1 and items[1].word == 'applebuffer', vim.inspect(items))
		vim.api.nvim_input '<C-e><Esc>'
	end)
end, 300)

vim.defer_fn(function()
	check(function()
		vim.cmd 'enew!'
		vim.lsp.get_client_by_id = function()
			return client
		end
		vim.lsp.get_clients = function()
			return { client }
		end
		-- Simulate Neovim's default setup for an attached completion-capable LSP.
		vim.bo.omnifunc = 'v:lua.vim.lsp.omnifunc'
		completion.attach(client, 0)
		type_prefix()
	end)
end, 400)

vim.defer_fn(function()
	check(function()
		local info = vim.fn.complete_info()
		local words = vim.tbl_map(function(item)
			return item.word
		end, info.items)
		assert(requests > 0, 'typing must request LSP completion')
		assert(vim.list_contains(words, 'applebuffer'), vim.inspect(words))
		assert(vim.list_contains(words, 'applelsp'), vim.inspect(words))
		assert(info.selected == -1, 'typing must not select a candidate')
		for index, word in ipairs(words) do
			if word == 'applelsp' then
				vim.api.nvim_input(string.rep('<Tab>', index) .. '<CR><Esc>')
				break
			end
		end
	end)
end, 800)

vim.defer_fn(function()
	check(function()
		assert(vim.api.nvim_get_current_line() == 'applelsp', 'Enter must accept the selected LSP item')
		vim.bo.buftype = 'nofile'
		assert(not vim.bo.autocomplete, 'changing to a special buffer must disable autocomplete')
		vim.bo.buftype = ''
		assert(vim.bo.autocomplete, 'changing to a normal buffer must enable autocomplete')
		assert(vim.v.errmsg == '', vim.v.errmsg)
	end)
	vim.api.nvim_out_write 'PASS: automatic buffer and LSP completion integration\n'
	vim.cmd 'qa!'
end, 900)
