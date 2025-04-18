local dap = require 'dap'
local ui = require 'dapui'

require('dapui').setup()
require('dap-go').setup()

dap.listeners.before.attach.dapui_config = function()
	ui.open()
end
dap.listeners.before.launch.dapui_config = function()
	ui.open()
end
dap.listeners.before.event_terminated.dapui_config = function()
	ui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
	ui.close()
end

-- Keymaps
vim.keymap.set('n', '<space><C-b>', dap.toggle_breakpoint)
vim.keymap.set('n', '<space><C-r>', dap.run_to_cursor)
vim.keymap.set('n', '<space><C-e>', function()
	require('dapui').eval(nil, { enter = true })
end)
vim.keymap.set('n', '<F1>', dap.continue)
vim.keymap.set('n', '<F2>', dap.step_over)
vim.keymap.set('n', '<F3>', dap.step_into)
vim.keymap.set('n', '<F4>', dap.step_out)
vim.keymap.set('n', '<F5>', dap.step_back)
vim.keymap.set('n', '<F12>', dap.restart)

require('nvim-dap-virtual-text').setup()

local elixir_ls_debugger = vim.fn.exepath 'elixir-ls-debugger'
if elixir_ls_debugger ~= '' then
	dap.adapters.mix_task = {
		type = 'executable',
		command = elixir_ls_debugger,
	}

	dap.configurations.elixir = {
		{
			type = 'mix_task',
			name = 'phoenix server',
			task = 'phx.server',
			request = 'launch',
			projectDir = '${workspaceFolder}',
			exitAfterTaskReturns = false,
			debugAutoInterpretAllModules = false,
		},
	}
end

dap.configurations.lua = {
	{
		type = 'nlua',
		request = 'attach',
		name = 'Attach to running Neovim instance',
	},
}
dap.adapters.nlua = function(callback, config)
	callback { type = 'server', host = config.host or '127.0.0.1', port = config.port or 8086 }
end
