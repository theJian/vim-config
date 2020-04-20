if exists("b:did_ftplugin_after")
  finish
endif
let b:did_ftplugin_after = 1

if has('spell')
    setlocal spell
endif

setlocal textwidth=72
