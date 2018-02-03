if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

" tab
setlocal tabstop=2 softtabstop=2 shiftwidth=2 expandtab

packadd 'vim-reason-plus'
