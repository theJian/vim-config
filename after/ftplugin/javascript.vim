if exists("b:did_ftplugin_after")
  finish
endif
let b:did_ftplugin_after = 1

" indentation rule
set cindent
set cinoptions+=J1

" possible folding method
setlocal foldmethod=indent

" this allows gf and :find to work. Fix path to your needs
setlocal suffixesadd=.js

" tab
setlocal tabstop=2 softtabstop=2 shiftwidth=2 expandtab

nnoremap <buffer> <silent> K :call LanguageClient#textDocument_hover()<CR>
nnoremap <buffer> <silent> gd :call LanguageClient#textDocument_definition()<CR>

packadd vim-flow
