"""""""""""""""""""""""""""""""""""""""""""""""
"                   General                   "
"""""""""""""""""""""""""""""""""""""""""""""""
set nocompatible
syntax enable
filetype plugin indent on
set autoindent
set cindent
set cinoptions+=J1
set mouse=nc

" compatible options
set cpoptions+=n
set cpoptions+=y
set cpoptions-=;

" tab
set softtabstop=4
set shiftwidth=4
set smarttab

" Open new splits on the right/bottom
set splitbelow
set splitright

" Encoding
set encoding=utf-8

" Set to auto read when a file is changed from the outside
set autoread

" hide changed buffer instead close
set hidden

" Good performance
set lazyredraw
set ttyfast

" BadWhitespace
highlight BadWhitespace ctermbg=red guibg=red

"Searching
set hlsearch
set incsearch
set ignorecase
set smartcase

" explore files caseinsensitively
set wildignorecase

" Fold
set foldenable
set foldmethod=indent
set foldlevelstart=4
set foldnestmax=10

" file format
set fileformat=unix

" Enable All Python Syntax Highlight Features
let python_highlight_all=1

" Python indent
let g:pyindent_open_paren = '&sw'

set bs=2
set wrap linebreak
set ruler
set wildmenu
set nobackup
set noswapfile
set virtualedit=onemore

" Open Buffers on Their Own Tab
" au BufAdd,BufNewFile * nested tab sball

" Automatic create directory when it doesn't exist
augroup Mkdir
	autocmd!
	autocmd BufNewFile *
		\ if !isdirectory(expand("<afile>:p:h")) |
			\ call mkdir(expand("<afile>:p:h"), "p") |
		\ endif
augroup END

"""""""""""""""""""""""""""""""""""""""""""""""
"               User Interface                "
"""""""""""""""""""""""""""""""""""""""""""""""
" colorscheme
set background=dark
colorscheme fethoi

" true color
set termguicolors

set guitablabel=%t\ %M

" show invisiable chars
set list
set listchars=tab:›\ ,trail:•,extends:§,nbsp:•
hi NonText guifg=#2F3740
hi SpecialKey guifg=#2F3740

" matches highlight delay
set matchtime=3

" highlight font settings
hi Comment gui=italic

" Matches highlighting colors
hi MatchParen cterm=underline ctermbg=none ctermfg=LightGreen gui=underline guibg=NONE guifg=LightGreen

" Folded highlighting colors
hi Folded ctermbg=none ctermfg=DarkCyan guibg=NONE guifg=DarkCyan

" Hightlight in diff
hi DiffAdd    cterm=bold
hi DiffDelete cterm=bold
hi DiffChange cterm=bold
hi DiffText   cterm=bold

"Font
set gfn=Inconsolata\ 16

" Simplify Gvim window
set guioptions=av

" Statusline
set laststatus=2
set statusline=%f " file path
set statusline+=%1*%m%*%r%h%w "file info
set statusline+=%= "switch to the right side
set statusline+=(%{&ff}/%Y) " file type
set statusline+=\  " separator
set statusline+=(line\ %l\/%L,\ col\ %c) " cusor position
set statusline+=\  " seperator
set statusline+=%<%P " percentage
" highlight modified flag
hi User1 ctermfg=red guifg=red

"Cursor
"" Change cursor shape in different mode(for VTE compatible terminals)
let &t_SI = "\<Esc>[6 q"
let &t_SR = "\<Esc>[4 q"
let &t_EI = "\<Esc>[2 q"

set guicursor+=a:blinkon0
set scrolloff=3
set cursorcolumn
set cursorline

"Only have cursorline in current window
au WinLeave * set nocursorline
au WinLeave * set nocursorcolumn
au WinEnter * set cursorline
au WinEnter * set cursorcolumn

" Use relative number
set relativenumber

" Add a colored line at 81 column
set colorcolumn=81

" Solid window split border
set fillchars+=vert:\ 

" dotted folded line
set fillchars+=fold:┄

" maximize window
if has("gui_running")
        set lines=999 columns=999
endif

set number
set showcmd
set showmode
set showmatch
set showbreak=↪\ \ \ 

"""""""""""""""""""""""""""""""""""""""""""""""
"                Key Mapping                  "
"""""""""""""""""""""""""""""""""""""""""""""""
" set leader key
let mapleader="\<space>"

" exit insert mode without esc
inoremap jk <ESC>

" Treat long lines as break lines
nnoremap j gj
nnoremap k gk

" Toggle folding
nnoremap <leader><space> za

" To save, press <leader>w
nnoremap <leader>w :w<CR>

" To edit, press <leader>e
nnoremap <leader>e :e <C-R>=expand("%:h") . "/" <CR>

" To create a file
nnoremap <leader>n :n <C-R>=expand("%:h") . "/" <CR>

" Add an empty line without insert mode
nnoremap <C-CR> o<Esc>
nnoremap <S-CR> O<Esc>

" Add an empty line in insert mode
inoremap <C-j>  <Esc>o
inoremap <C-CR> <Esc>o
inoremap <S-CR> <Esc>O

" Split
nnoremap <leader>h :<C-u>split<CR>
nnoremap <leader>v :<C-u>vsplit<CR>

" Tabs
nnoremap <C-S-Tab> gT
nnoremap <C-Tab> gt
nnoremap <C-n> :tabnew<CR>

" Set working directory
nnoremap <leader>. :lcd %:p:h<CR>

" Copy/Paste/Cut
vnoremap YY "+y<CR>
nnoremap PP "+p<CR>
vnoremap XX "+x<CR>

" Close buffer
nnoremap <leader>q :bp\|bd #<CR>

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
" inoremap <C-k> <esc>g~iwea

" delete word
inoremap <C-BS> <C-W>

" select last changed text
nnoremap <expr> gp '`[' . strpart(getregtype(), 0, 1) . '`]'

" Command line editing
cnoremap <C-h> <Left>
cnoremap <C-l> <Right>

" map each number to its shift-key character
inoremap 1 !
inoremap 2 @
inoremap 3 #
inoremap 4 $
inoremap 5 %
inoremap 6 ^
inoremap 7 &
inoremap 8 *
inoremap 9 (
inoremap 0 )
" and then the opposite
inoremap ! 1
inoremap @ 2
inoremap # 3
inoremap $ 4
inoremap % 5
inoremap ^ 6
inoremap & 7
inoremap * 8
inoremap ( 9
inoremap ) 0

"""""""""""""""""""""""""""""""""""""""""""""""
"              Files Specified                "
"""""""""""""""""""""""""""""""""""""""""""""""

" Filetype detect
au BufRead,BufNewFile *.hbs set filetype=handlebars

" Flagging Unnecessary Whitespace
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h,*js,*jsx match BadWhitespace /\s\+$/

" Python
augroup file_python
    au!
    au BufNewFile,BufRead *.py set tabstop=4
    au BufNewFile,BufRead *.py set softtabstop=4
    au BufNewFile,BufRead *.py set shiftwidth=4
    au BufNewFile,BufRead *.py set expandtab
    au BufNewFile *.py
    \ 0put = '#!/usr/bin/python3' |
    \ 1put = '#-*- coding: utf-8 -*-' |
augroup END

" Javascript/CSS/HTML
augroup file_js_css_html
    au!
    au BufNewFile,BufRead *.js,*.html,*.css set tabstop=2
    au BufNewFile,BufRead *.js,*.html,*.css set softtabstop=2
    au BufNewFile,BufRead *.js,*.html,*.css set shiftwidth=2
    au BufNewFile,BufRead *.js,*.html,*.css set expandtab
augroup END

" Elm
augroup file_elm
    au!
    au BufNewFile,BufRead *.elm set tabstop=4
    au BufNewFile,BufRead *.elm set softtabstop=4
    au BufNewFile,BufRead *.elm set shiftwidth=4
augroup END

" lisp
au FileType lisp setlocal lisp autoindent showmatch cpoptions-=mp

augroup HelpInTabs
	au!
	au BufEnter *.txt call HelpInNewTab()
augroup END

" Only apply to help files
function! HelpInNewTab()
	if &buftype == 'help'
		" convert help window to tab
		execute "normal \<C-W>T"
	endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""
"              Plugin Settings                "
"""""""""""""""""""""""""""""""""""""""""""""""

" ack
let g:ackprg="ag --vimgrep"

" Command-T
"" Mapping
nmap <silent> <Leader>k <Plug>(CommandTMRU)
"" ignore search
let g:CommandTWildIgnore=&wildignore . "*/bower_components,*/node_modules,*/.git,*/__pycache__,*/elm-stuff,*/lib"
"" use current working path as root for search files
let g:CommandTTraverseSCM="pwd"

" Emmet
"" Enable Only in Insert Mode
let g:user_emmet_mode='i'
"" Enable only for html, css
let g:user_emmet_install_global = 0
autocmd FileType xhtml,html,handlebars,css,less,sass,scss EmmetInstall
"" Redefine trigger key
let g:user_emmet_leader_key=','

" Netrw
let g:netrw_liststyle=0
let g:netrw_keepdir=1

" delimitMate
let delimitMate_expand_cr = 1
let delimitMate_expand_space = 1
let delimitMate_jump_expansion = 1

" ultisnips
let g:UltiSnipsSnippetDirectories=[$HOME.'/.vim/UltiSnips']
let g:UltiSnipsSnippetsDir=$HOME.'/.vim/UltiSnips'
let g:UltiSnipsExpandTrigger="<c-j>"
let g:UltiSnipsListSnippets="<c-b>"
let g:UltiSnipsJumpForwardTrigger="<c-j>"
let g:UltiSnipsJumpBackwardTrigger="<c-k>"
let g:UltiSnipsEditSplit="vertical"

" YouCompleteMe
" Debug
" let g:ycm_server_keep_logfiles = 1
" let g:ycm_server_log_level = 'debug'
""  Python3 Semantic Completion
let g:ycm_python_binary_path = 'python'
""  Rust Semantic Completion
let g:ycm_rust_src_path = '/usr/src/rust/src'
"" invoke completion key
let g:ycm_key_invoke_completion = '<C-h>'
"" Go To Definition
nnoremap <leader>gd  :YcmCompleter GoTo<CR>
nnoremap <leader>gr  :YcmCompleter GoToReferences<CR>
"" Autoclose Preview Window when leaves insert mode
let g:ycm_autoclose_preview_window_after_insertion = 1
if !exists("g:ycm_semantic_triggers")
          let g:ycm_semantic_triggers = {}
endif
let g:ycm_semantic_triggers['typescript'] = ['.']

"" python with virtualenv support
py << EOF
import os
import sys
if 'VIRTUAL_ENV' in os.environ:
  project_base_dir = os.environ['VIRTUAL_ENV']
  activate_this = os.path.join(project_base_dir, 'bin/activate_this.py')
  execfile(activate_this, dict(__file__=activate_this))
EOF
