" NeoBundle Scripts-----------------------------
if has('vim_starting')
  if &compatible
    set nocompatible               " Be iMproved
  endif

  " Required:
  set runtimepath+=/home/jian/.vim/bundle/neobundle.vim/
endif

" Required:
call neobundle#begin(expand('/home/jian/.vim/bundle'))

" Let NeoBundle manage NeoBundle
" Required:
NeoBundleFetch 'Shougo/neobundle.vim'

" Add or remove your Bundles here:

" Comments
NeoBundle 'tpope/vim-commentary'

" Auto-complete
NeoBundle 'Valloric/YouCompleteMe'

" Auto pairs
" NeoBundle 'jiangmiao/auto-pairs'
NeoBundle 'Raimondi/delimitMate'

" File navigation
NeoBundle 'wincent/command-t'

" Code Searching
NeoBundle 'rking/ag.vim'

" Emmet
NeoBundle 'mattn/emmet-vim'

" Colorscheme
NeoBundle 'whatyouhide/vim-gotham'
NeoBundle 'atelierbram/vim-colors_duotones'
" You can specify revision/branch/tag.

" Required:
call neobundle#end()

" Required:
filetype plugin indent on

" If there are uninstalled bundles found on startup,
" this will conveniently prompt you to install them.
NeoBundleCheck
"End NeoBundle Scripts-------------------------

"""""""""""""""""""""""""""""""""""""""""""""""
"                   General                   "
"""""""""""""""""""""""""""""""""""""""""""""""
set nocompatible
syntax enable
set autoindent
set cindent
set cinoptions=J1,(s,m1

" tab
set shiftwidth=2
set tabstop=2
set expandtab
set smarttab

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

"Fold
set foldmethod=indent
set nofoldenable

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

"""""""""""""""""""""""""""""""""""""""""""""""
"               User Interface                "
"""""""""""""""""""""""""""""""""""""""""""""""
" colorscheme
set background=dark
if has("gui_running")
    colorscheme gotham
else
    colorscheme gotham
    " colorscheme duotone-darksea
endif

set guitablabel=%t\ %M

" show invisiable chars
set list
set listchars=tab:»•,trail:•,extends:#,nbsp:•
hi NonText guifg=#2F3740
hi SpecialKey guifg=#2F3740

" matches highlight delay
set matchtime=3

"Font
set gfn=Hack\ 10

"Simplify Gvim window
set guioptions=av

"Statusline
set laststatus=2
hi statusline ctermbg=0
set statusline=#%-3.3n " buffer id
set statusline+=%F " file path
set statusline+=%m%r%h%w "file info
set statusline+=%= "switch to the right side
set statusline+=(%{&ff}/%Y) " file type
set statusline+=\  " separator
set statusline+=(line\ %l\/%L,\ col\ %c) " cusor position
set statusline+=\  " seperator
set statusline+=%<%P " percentage

"Cursor
set guicursor+=a:blinkon0
set scrolloff=3
set cursorline
hi cursorline cterm=NONE ctermbg=NONE ctermfg=NONE
set cursorcolumn
hi cursorcolumn cterm=NONE ctermbg=NONE ctermfg=NONE

" Use relative number
set relativenumber

set number
set showcmd
set showmode
set showmatch
set showbreak=ʟ\ 

"""""""""""""""""""""""""""""""""""""""""""""""
"                Key Mapping                  "
"""""""""""""""""""""""""""""""""""""""""""""""
" set leader key
let mapleader="\<space>"

" Folding
nnoremap <leader><space> za

" Treat long lines as break lines
nnoremap j gj
nnoremap k gk

" To save, press <leader>w
nnoremap <leader>w :w<CR>

" To edit, press <leader>e
nnoremap <leader>e :e <C-R>=expand("%:p:h") . "/" <CR>

" To create a file
nnoremap <leader>n :n <C-R>=expand("%:p:h") . "/" <CR>

" To edit in a new tab, press <leader>te
" noremap <leader>te :tabe <C-R>=expand("%:p:h") . "/" <CR>

" Add an empty line without insert mode
nnoremap <S-Enter> O<Esc>
nnoremap <CR> o<Esc>

" Add an empty line in insert mode
inoremap <C-Enter> <Esc>o
inoremap <C-S-Enter> <Esc>O

" Split
nnoremap <leader>h :<C-u>split<CR>
nnoremap <leader>v :<C-u>vsplit<CR>

" Tabs
nnoremap <C-S-Tab> gT
nnoremap <C-Tab> gt
nnoremap <C-t> :tabnew<CR>

" Set working directory
nnoremap <leader>. :lcd %:p:h<CR>

" Copy/Paste/Cut
vnoremap YY "+y<CR>
nnoremap PP "+p<CR>
vnoremap XX "+x<CR>

" Buffer nav
nnoremap <leader>[ :bp<CR>
nnoremap <leader>] :bn<CR>

" Close buffer
nnoremap <leader>\ :bd<CR>

" Clean search (highlight)
nnoremap <silent> <BS> :noh<CR>

" Switching windows
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
nnoremap <C-h> <C-w>h
nnoremap <C-w> <C-w>q

" shifting
vnoremap < <gv
vnoremap > >gv

" Move visual block
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" Uppercase word
inoremap <C-j> <esc>gUiwea

" delete word
inoremap <C-BS> <C-w>

"""""""""""""""""""""""""""""""""""""""""""""""
"              Files Specified                "
"""""""""""""""""""""""""""""""""""""""""""""""
" Flagging Unnecessary Whitespace
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/

" Python
augroup file_python
    au!
    au BufNewFile,BufRead *.py set tabstop=4
    au BufNewFile,BufRead *.py set softtabstop=4
    au BufNewFile,BufRead *.py set shiftwidth=4
    au BufNewFile,BufRead *.py set expandtab
    au BufNewFile,BufRead *.py set fileformat=unix
    au BufNewFile *.py
    \ 0put = '#!/usr/bin/python3' |
    \ 1put = '#-*- coding: utf-8 -*-' |
augroup END

" Javascript/CSS/HTML
augroup file_js_css_html
    au!
    au BufNewFile,BufRead *.js,*.html,*.css set tabstop=4
    au BufNewFile,BufRead *.js,*.html,*.css set softtabstop=4
    au BufNewFile,BufRead *.js,*.html,*.css set shiftwidth=4
augroup END

"""""""""""""""""""""""""""""""""""""""""""""""
"              Plugin Settings                "
"""""""""""""""""""""""""""""""""""""""""""""""
" ag
" highlight
let g:ag_highlight=1

" Command-T
"" ignore search
let g:CommandTWildIgnore=&wildignore . ",**/bower_components/*,**/node_modules/*,**/.git/*,**/__pycache__/*"

" Emmet
"" Enable Only in Insert Mode
let g:user_emmet_mode='i'
"" Enable for All Filetype
let g:user_emmet_install_global = 1
"" Redefine trigger key
let g:user_emmet_leader_key=','

" Netrw
let g:netrw_liststyle=0
let g:netrw_keepdir= 0

" YouCompleteMe
" Debug
" let g:ycm_server_keep_logfiles = 1
" let g:ycm_server_log_level = 'debug'
""  Python3 Semantic Completion
let g:ycm_python_binary_path = '/usr/bin/python3'
"" Go To Definition
noremap <leader>g  :YcmCompleter GoToDefinitionElseDeclaration<CR>
"" Autoclose Preview Window
let g:ycm_autoclose_preview_window_after_completion=1
"" python with virtualenv support
py << EOF
import os
import sys
if 'VIRTUAL_ENV' in os.environ:
  project_base_dir = os.environ['VIRTUAL_ENV']
  activate_this = os.path.join(project_base_dir, 'bin/activate_this.py')
  execfile(activate_this, dict(__file__=activate_this))
EOF

"""""""""""""""""""""""""""""""""""""""""""""""
"                Easy Snippets                "
"""""""""""""""""""""""""""""""""""""""""""""""

augroup common_snippets
    au!
    au Filetype * :iabbrev <buffer> ret; return
augroup END

augroup javascript_snippets
    au!
    au Filetype javascript :iabbrev <buffer> func; function
    au Filetype javascript :iabbrev <buffer> log; console.log
augroup END

