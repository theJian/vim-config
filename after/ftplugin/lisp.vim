if exists("b:did_ftplugin_after")
  finish
endif
let b:did_ftplugin_after = 1

setlocal expandtab
setlocal autoindent lisp showmatch cpoptions-=mp

" possible folding method
setlocal foldmethod=marker foldmarker=(,) foldminlines=1

" this allows gf and :find to work. Fix path to your needs
setlocal suffixesadd=.lisp

" packadd vim-parinfer
packadd rainbow_parentheses.vim
packadd vim-sexp

execute 'RainbowParentheses'
