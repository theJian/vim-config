if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal lisp autoindent showmatch cpoptions-=mp

" possible folding method
setlocal foldmethod=marker foldmarker=(,) foldminlines=1

" this allows gf and :find to work. Fix path to your needs
setlocal suffixesadd=.lisp

