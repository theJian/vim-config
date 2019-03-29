if exists("b:did_ftplugin_after")
  finish
endif
let b:did_ftplugin_after = 1

nnoremap <buffer> <silent> K :call LanguageClient#textDocument_hover()<CR>
nnoremap <buffer> <silent> gd :call LanguageClient#textDocument_definition()<CR>
