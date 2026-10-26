-- nvim --headless -u NONE -i NONE -l tests/workspaces_restart.lua
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, 'p')
temp = vim.uv.fs_realpath(temp)
local script = temp .. '/child.lua'
vim.fn.writefile(
	vim.split(
		[=[
local mode, root, config = arg[1], arg[2], arg[3]
vim.opt.rtp:prepend(config)
vim.o.hidden, vim.o.swapfile = true, false
local store = require 'workspace_store'
store.directory = function() return root .. '/state' end
local w, p = require 'workspaces', require 'projects'
w.setup()
p.setup()
if mode == 'write' then
  vim.fn.mkdir(root .. '/project', 'p')
  vim.fn.writefile({ 'disk content' }, root .. '/project/file.txt')
  p.add(root .. '/project')
  w.project(root .. '/project')
  vim.cmd.edit(vim.fn.fnameescape(root .. '/project/file.txt'))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved content', 'cursor line' })
  vim.api.nvim_win_set_cursor(0, { 2, 3 })
  vim.cmd.vsplit()
  vim.cmd.split()
  p.scratch(false)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'persistent project notes' })
  w.rename('persistent')
  w.save('individual')
  vim.cmd('qa!')
else
  assert(vim.tbl_contains(p.list(), root .. '/project'))
  assert(w.restore(store.read('last-session'), true))
  assert(w.current().name == 'persistent')
  assert(vim.fn.getcwd() == root .. '/project')
  assert(#vim.api.nvim_tabpage_list_wins(0) == 3)
  assert(vim.api.nvim_get_current_line() == 'persistent project notes')
  local scratch = vim.api.nvim_get_current_buf()
  p.scratch(false)
  assert(vim.api.nvim_get_current_buf() == scratch)
  local file = vim.fn.bufnr(root .. '/project/file.txt')
  assert(vim.bo[file].modified)
  assert(vim.api.nvim_buf_get_lines(file, 0, -1, false)[1] == 'unsaved content')
  assert(vim.fn.readfile(root .. '/project/file.txt')[1] == 'disk content')
  local found = false
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == file then
      assert(vim.deep_equal(vim.api.nvim_win_get_cursor(win), { 2, 3 }))
      found = true
    end
  end
  assert(found)
  assert(store.read('saved').individual.workspaces[1].name == 'persistent')
  vim.cmd('qa!')
end
]=],
		'\n'
	),
	script
)
for _, mode in ipairs { 'write', 'read' } do
	local result = vim.system(
		{ vim.v.progpath, '--headless', '-u', 'NONE', '-i', 'NONE', '-l', script, mode, temp, vim.fn.getcwd() },
		{ text = true }
	):wait()
	assert(result.code == 0, mode .. ': ' .. result.stderr)
end
vim.fn.delete(temp, 'rf')
print 'PASS process restart preserves registry, layouts, views, scratch text and unsaved file contents'
