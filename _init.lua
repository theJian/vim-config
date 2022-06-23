-- General

-- Mouse
vim.o.mouse = 'nc'

-- Compatible options
vim.opt.cpoptions:append('n')
vim.opt.cpoptions:append('y')
vim.opt.cpoptions:remove(';')

-- Tab
vim.o.softtabstop = 4
vim.o.tabstop = 4
vim.o.shiftwidth = 4
