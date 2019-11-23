"─── General ───────────────────────────────────────────────────────────────────

" Mouse
set mouse=nc

" Compatible options
set cpoptions+=n
set cpoptions+=y
set cpoptions-=;

" Tab
set softtabstop=4
set tabstop=4
set shiftwidth=4

" Open new splits on the right/bottom
set splitbelow
set splitright

" Hide changed buffer instead close
set hidden

" Good performance
set lazyredraw

"Searching
set ignorecase
set smartcase

" Explore files case-insensitively
set wildignorecase

" Folding
set foldenable
set foldlevelstart=4
set foldnestmax=10
set foldopen-=block

" File format
set fileformat=unix

" Wrap long lines
set wrap
set linebreak

" No backup files, no swap files
set nobackup
set noswapfile

" Allow cursor to move just past the end of the line
set virtualedit=onemore

" Ask confirmation for certain things like when quitting before saving
set confirm

" Turn off bell
set novisualbell
set noerrorbells

" Search stop at the end of file
set nowrapscan

" Yank text to system clipboard
set clipboard+=unnamedplus

"─── User Interface ────────────────────────────────────────────────────────────

set termguicolors

" Colorscheme
colorscheme Mogao

" Show invisiable chars
set list
set listchars=tab:┊\ ,trail:•,extends:§,nbsp:·

" Matches highlight delay
set showmatch
set matchtime=3

" Highlight font settings
highlight Comment cterm=italic

" Font
set guifont=IBM\ Plex\ Mono:h11

" Statusline
set laststatus=2 " always show statusline
set statusline=\ %f " file path
set statusline+=%1*%m%*%r%h%w "file info
set statusline+=%= "switch to the right side
set statusline+=Ln\ %l\/%L\ [%<%p%%]\ \ Col\ %c " cusor position
set statusline+=\ \  " seperator
set statusline+=%{&ff}/%Y\  " file type
" Highlight modified flag
highlight User1 ctermbg=1 guibg=#7c0615 guifg=White

" Mimium number of screen lines to keep above or below the cursor
set scrolloff=2

" Highlight cursor position
set cursorcolumn
set cursorline

" Use relative number
set number
set relativenumber

" Clear highlight above 120 characters width
set synmaxcol=120

" Solid window split border
set fillchars+=vert:¦

" Wrapped line mark
set showbreak=↪\ \ \ 

" Show message in insert
set showmode

" Always show sign column
set signcolumn=yes

"─── Key Mapping ───────────────────────────────────────────────────────────────

" Set leader key
let mapleader="\<space>"

" Exit insert mode without esc
inoremap jk <ESC>

" Treat long lines as break lines
nnoremap <silent> j :<C-u>execute 'normal!' (v:count > 1 ? "m'" . v:count : 'g') . 'j'<CR>
nnoremap <silent> k :<C-u>execute 'normal!' (v:count > 1 ? "m'" . v:count : 'g') . 'k'<CR>

" Toggle folding
nnoremap <leader><space> za

" To save, press <leader>w
nnoremap <leader>w :w<CR>

" To create a file
nnoremap <expr> <leader>n ':n ' . GetRelDir()

" Split
nnoremap <leader>h :<C-u>split<CR>
nnoremap <leader>v :<C-u>vsplit<CR>

" Tabs
nnoremap <leader>t :tabnew<CR>

" Close buffer
nnoremap <leader>q :<C-u>bp\|bd #<CR>

" Clean search (highlight)
nnoremap <silent> <BS> :noh<CR>

" Switching windows
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
nnoremap <C-h> <C-w>h
nnoremap <C-q> <C-w>q

" shifting
vnoremap < <gv
vnoremap > >gv

" Move visual block
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" Uppercase/Lowercase word
inoremap <C-u> <esc>g~iwea

" Select last changed text
nnoremap <expr> gp '`[' . strpart(getregtype(), 0, 1) . '`]'

" Command line cursor move
cnoremap <C-h> <Left>
cnoremap <C-l> <Right>
cnoremap <C-k> <Up>
cnoremap <C-j> <Down>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>

" Visual mode pressing * or # searches for the current selection
vnoremap <silent> * :<C-u>call VisualSelection()<CR>/<C-R>=@/<CR><CR>
vnoremap <silent> # :<C-u>call VisualSelection()<CR>?<C-R>=@/<CR><CR>

" Open files fuzzyfinder
nnoremap <leader>f :FFiles<CR>

" Open files under current directory
nnoremap <expr> <leader>e printf(":FFiles %s<CR>", GetFileDir())

" Swap ;/:
nnoremap ; :
nnoremap : ;
vnoremap ; :
vnoremap : ;

" Autocomplete trigger
inoremap <C-Space> <C-x><C-o>
inoremap <C-@> <C-x><C-o>

" Scroll
nnoremap <C-n> <C-e>
nnoremap <C-p> <C-y>

" Edit without clobbering register
nnoremap s "_c
nnoremap ss "_cc
nnoremap S "_C

"─── User Scripts ──────────────────────────────────────────────────────────────

" Sudo save
command! W w !sudo tee % > /dev/null

augroup Theme
    autocmd!
    autocmd BufWritePost Mogao.vim colorscheme Mogao
augroup END

" Automatically equalize splits when Vim is resized
augroup Resize
    autocmd!
    autocmd VimResized * wincmd =
augroup END

" Only have cursorline in current window
augroup CursorLine
    autocmd!
    autocmd winleave * set nocursorline
    autocmd winleave * set nocursorcolumn
    autocmd winenter * set cursorline
    autocmd winenter * set cursorcolumn
augroup END

" Automatic create directory when it doesn't exist
augroup Mkdir
    autocmd!
    autocmd BufNewFile *
                \ if !isdirectory(expand("<afile>:p:h")) |
                \ call mkdir(expand("<afile>:p:h"), "p") |
                \ endif
augroup END

" Open help file in new tab
augroup HelpInTabs
    autocmd!
    autocmd BufWinEnter *.txt call HelpInNewTab()
augroup END

" Only apply to help files
function! HelpInNewTab()
    if &buftype == 'help'
        " convert help window to tab
        execute "normal! \<C-W>T"
    endif
endfunction

" Show syntax highlighting groups for word under cursor
nnoremap <leader><C-P> :call <SID>SynStack()<CR>
function! <SID>SynStack()
    if !exists("*synstack")
        return
    endif
    echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')
endfunc

function! VisualSelection()
    let l:saved_reg = @"
    execute "normal! vgvy"
    let l:pattern = escape(@", "\\/.*'$^~[]")
    let l:pattern = substitute(l:pattern, "\n$", "", "")
    let @/ = l:pattern
    let @" = l:saved_reg
endfunction

function! GetFileDir()
    let dir = expand("%:h")
    if dir == ""
        let dir = "."
    endif
    return dir
endfunction

function! GetRelDir()
    let dir = GetFileDir()
    if dir == "."
        let dir = ""
    endif
    if dir != ""
        let dir = dir . '/'
    endif
    return dir
endfunction

"─── Plugin Settings ───────────────────────────────────────────────────────────

" complete
set completeopt+=menuone,noselect
autocmd CursorMovedI * if pumvisible() == 0|pclose|endif
autocmd InsertLeave * if pumvisible() == 0|pclose|endif
let g:mucomplete#enable_auto_at_startup = 1
let g:mucomplete#completion_delay = 100
let g:mucomplete#reopen_immediately = 0
let g:mucomplete#buffer_relative_paths = 1

" Netrw
let g:netrw_liststyle=0

" delimitMate
let delimitMate_expand_cr = 1
let delimitMate_expand_space = 1
let delimitMate_jump_expansion = 1

" ultisnips
let g:UltiSnipsSnippetDirectories=[fnamemodify($MYVIMRC, ":h") .'/UltiSnips']
let g:UltiSnipsExpandTrigger="<c-j>"
let g:UltiSnipsListSnippets="<c-l>"
let g:UltiSnipsJumpForwardTrigger="<c-j>"
let g:UltiSnipsJumpBackwardTrigger="<c-k>"
let g:UltiSnipsEditSplit="vertical"

" fit
let g:FitFilesFindCommand = "rg --color never --files <dir>"
let g:FitMatchCommand = "fzy --show-matches=<query>"

" yankstack
let g:yankstack_map_keys = 0
let g:yankstack_yank_keys = ['y', 'd']
nmap <leader>p <Plug>yankstack_substitute_older_paste
nmap <leader>P <Plug>yankstack_substitute_newer_paste

" vim-sexp
let g:sexp_enable_insert_mode_mappings = 0

" lsp
nnoremap <buffer> <silent> gd :call LanguageClient#textDocument_definition()<CR>
let g:LanguageClient_diagnosticsDisplay = {
    \ 1: {
    \   "name": "Error",
    \   "signText": "× ",
    \ },
    \ 2: {
    \   "name": "Warning",
    \   "signText": "¡ ",
    \ },
    \ 3: {
    \   "name": "Information",
    \   "signText": "‸ ",
    \ },
    \ 4: {
    \   "name": "Hint",
    \   "signText": "¿ ",
    \ },
    \ }
let g:LanguageClient_serverCommands = {
    \ 'javascript' : ['typescript-language-server', '--stdio'],
    \ 'typescript' : ['typescript-language-server', '--stdio'],
    \ 'ocaml'      : ['ocaml-language-server', '--stdio'],
    \ 'python'     : ['pyls'],
    \ 'rust'       : ['~/.cargo/bin/rustup', 'run', 'nightly', 'rls'],
    \ 'cpp'        : ['clangd'],
    \ }

" flowtype
let g:flow#omnifunc = 0
let g:flow#autoclose = 1

" rainbow pairs
let g:rainbow#pairs = [['(', ')'], ['[', ']'], ['{', '}']]

" far.vim
" let g:far#source='rg'

lua require 'packman'
