-- Data-only persistence: session files never execute editor commands.
local M = {}

function M.directory()
	return vim.fn.stdpath 'state' .. '/workspaces'
end

function M.write(name, value)
	local dir = M.directory()
	vim.fn.mkdir(dir, 'p', '0700')
	local path = dir .. '/' .. name .. '.json'
	local temp = path .. '.' .. vim.fn.getpid() .. '.tmp'
	local ok, err = pcall(function()
		assert(vim.fn.writefile({ vim.json.encode(value) }, temp) == 0, 'Cannot write ' .. temp)
		assert(vim.uv.fs_rename(temp, path))
	end)
	if not ok then
		vim.fn.delete(temp)
		error(err)
	end
end

function M.read(name)
	local path = M.directory() .. '/' .. name .. '.json'
	if vim.fn.filereadable(path) == 0 then
		return nil
	end
	local ok, value = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), '\n'))
	if not ok or type(value) ~= 'table' then
		error('Invalid workspace data: ' .. path)
	end
	return value
end

function M.pick(prompt, items, format, callback)
	return require('better_select').select(items, { prompt = prompt, format_item = format }, function(item)
		if item ~= nil then
			callback(item)
		end
	end)
end

function M.input(prompt, default, callback, completion)
	vim.ui.input({ prompt = prompt .. ': ', default = default, completion = completion }, function(value)
		if value and value:match '%S' then
			callback(value)
		end
	end)
end

return M
