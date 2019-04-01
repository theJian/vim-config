if exists("b:did_ftplugin_after")
  finish
endif
let b:did_ftplugin_after = 1

" tab
setlocal tabstop=2 softtabstop=2 shiftwidth=2 expandtab

nnoremap <buffer> <silent> K :call LanguageClient#textDocument_hover()<CR>
nnoremap <buffer> <silent> gd :call LanguageClient#textDocument_definition()<CR>
