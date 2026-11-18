-- Measures an attached 120x40 UI. Times are medians in milliseconds, not CI thresholds.
local child = vim.fn.jobstart({ 'nvim', '--embed', '-n', '-u', 'NONE', '-i', 'NONE' }, {
	rpc = true,
	env = { NVIM_LOG_FILE = vim.fn.tempname() },
})
local ok, err = pcall(function()
	vim.rpcrequest(child, 'nvim_ui_attach', 120, 40, { rgb = true })
	local results = vim.rpcrequest(
		child,
		'nvim_exec_lua',
		[[
		vim.opt.rtp:prepend(...)
		local start=vim.uv.hrtime()
		local wk=require('which_key')
		local load_ms=(vim.uv.hrtime()-start)/1e6
		local function median(values)
			table.sort(values)
			return values[math.ceil(#values/2)]
		end
		local rows={}
		for _, count in ipairs({100,1000,5000}) do
			wk.disable()
			vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true,false))
			for i=1,count do
				vim.keymap.set('n','<F6>'..vim.fn.nr2char(0x4e00+i)..'x','<Nop>',{buffer=true,desc='Synthetic mapping '..i})
			end
			local setup,refresh,render={},{},{}
			for iteration=1,15 do
				start=vim.uv.hrtime()
				wk.setup()
				setup[#setup+1]=(vim.uv.hrtime()-start)/1e6
				start=vim.uv.hrtime()
				wk.refresh()
				refresh[#refresh+1]=(vim.uv.hrtime()-start)/1e6
				local original_refresh, original_getchar=wk.refresh,vim.fn.getcharstr
				local refresh_ms, calls=0,0
				wk.refresh=function()
					local t=vim.uv.hrtime(); original_refresh(); refresh_ms=(vim.uv.hrtime()-t)/1e6
				end
				vim.fn.getcharstr=function()
					calls=calls+1
					return calls==1 and '' or vim.keycode('<Esc>')
				end
				start=vim.uv.hrtime()
				wk.show('<F6>')
				render[#render+1]=(vim.uv.hrtime()-start)/1e6-refresh_ms
				wk.refresh,vim.fn.getcharstr=original_refresh,original_getchar
			end
			rows[#rows+1]={count=count,setup=median(setup),refresh=median(refresh),render=median(render)}
		end
		wk.disable()
		return {load=load_ms,rows=rows}
	]],
		{ vim.fn.getcwd() }
	)
	print(('Module load: %.3f ms'):format(results.load))
	print 'Mappings | setup | refresh/index | render/close (ms)'
	for _, row in ipairs(results.rows) do
		print(('%d | %.3f | %.3f | %.3f'):format(row.count, row.setup, row.refresh, row.render))
	end
end)
vim.fn.jobstop(child)
assert(ok, err)
