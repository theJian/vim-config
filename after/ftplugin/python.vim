if exists("b:did_ftplugin_after")
  finish
endif
let b:did_ftplugin_after = 1

" possible folding method
setlocal foldmethod=indent

" this allows gf and :find to work. Fix path to your needs
setlocal suffixesadd=.py

" tab
setlocal tabstop=4 softtabstop=4 shiftwidth=4 expandtab
