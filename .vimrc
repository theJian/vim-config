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
set shiftwidth=4
set tabstop=4
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
    colorscheme duotone-darksea
endif

set guitablabel=%t\ %M

" show invisiable chars
set list
set listchars=tab:»•,trail:•,extends:#,nbsp:•
hi NonText guifg=#2F3740
hi SpecialKey guifg=#2F3740

"Font
set gfn=Hack\ 10

"Simplify Gvim window
set guioptions=av

"Statusline
set laststatus=2
hi statusline ctermbg=0
set statusline=#%-3.3n\%F%m%r%h%w%=(%{&ff}/%Y)\ (line\ %l\/%L,\ col\ %c)\ %<%P

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
noremap <leader><space> za

" Treat long lines as break lines
map j gj
map k gk

" To save, press <leader>w
nmap <leader>w :w<CR>

" To edit, press <leader>e
noremap <leader>e :e <C-R>=expand("%:p:h") . "/" <CR>

" To edit in a new tab, press <leader>te
" noremap <leader>te :tabe <C-R>=expand("%:p:h") . "/" <CR>

" Add an empty line without insert mode
nmap <S-Enter> O<Esc>
nmap <CR> o<Esc>

" Add an empty line in insert mode
imap <C-Enter> <Esc>o
imap <C-S-Enter> <Esc>O

" Split
noremap <leader>h :<C-u>split<CR>
noremap <leader>v :<C-u>vsplit<CR>

" Tabs
nnoremap <C-S-Tab> gT
nnoremap <C-Tab> gt
nnoremap <C-t> :tabnew<CR>

" Set working directory
nnoremap <leader>. :lcd %:p:h<CR>

" Copy/Paste/Cut
noremap YY "+y<CR>
noremap PP "+p<CR>
noremap XX "+x<CR>

" Buffer nav
noremap <leader>[ :bp<CR>
noremap <leader>] :bn<CR>

" Close buffer
noremap <leader>\ :bd<CR>

" Clean search (highlight)
nnoremap <silent> <leader><BS> :noh<CR>

" Switching windows
noremap <C-j> <C-w>j
noremap <C-k> <C-w>k
noremap <C-l> <C-w>l
noremap <C-h> <C-w>h
noremap <C-w> <C-w>q

" shifting
vmap < <gv
vmap > >gv

" Move visual block
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

"""""""""""""""""""""""""""""""""""""""""""""""
"              Files Specified                "
"""""""""""""""""""""""""""""""""""""""""""""""
" Flagging Unnecessary Whitespace
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/

" Python
au BufNewFile,BufRead *.py set tabstop=4
au BufNewFile,BufRead *.py set softtabstop=4
au BufNewFile,BufRead *.py set shiftwidth=4
au BufNewFile,BufRead *.py set expandtab
au BufNewFile,BufRead *.py set fileformat=unix
au BufNewFile *.py
\ 0put = '#!/usr/bin/python3' |
\ 1put = '#-*- coding: utf-8 -*-' |

" Javascript/CSS/HTML
au BufNewFile,BufRead *.js,*.html,*.css set tabstop=2
au BufNewFile,BufRead *.js,*.html,*.css set softtabstop=2
au BufNewFile,BufRead *.js,*.html,*.css set shiftwidth=2

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
map <leader>g  :YcmCompleter GoToDefinitionElseDeclaration<CR>
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
