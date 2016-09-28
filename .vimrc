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

" edit config
NeoBundle 'editorconfig/editorconfig-vim'

" expand region
NeoBundle 'terryma/vim-expand-region'

" surround
NeoBundle 'tpope/vim-surround'

" rust support
NeoBundle 'rust-lang/rust.vim'

" elm support
NeoBundle 'ElmCast/elm-vim'

" Colorscheme
NeoBundle 'whatyouhide/vim-gotham'
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
set cinoptions+=J1
set mouse=nc

" tab
set shiftwidth=2
set tabstop=2
set softtabstop=2
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

" explore files caseinsensitively
set wildignorecase

"Fold
set foldmethod=manual

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

"""""""""""""""""""""""""""""""""""""""""""""""
"               User Interface                "
"""""""""""""""""""""""""""""""""""""""""""""""
" colorscheme
set background=dark
if has("gui_running")
    colorscheme gotham
else
    colorscheme gotham256
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
set gfn=Hack\ 12

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

" Add a colored line at 121 column
set colorcolumn=120

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
nnoremap <C-Enter> o<Esc>
nnoremap <S-Enter> O<Esc>

" Add an empty line in insert mode
inoremap <C-Enter> <Esc>o
inoremap <S-Enter> <Esc>O

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

" Close buffer
nnoremap <leader>q :bd<CR>

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

" Uppercase word
inoremap <C-l> <esc>g~iwea

" delete word
inoremap <C-BS> <C-w>

" highlight last inserted text
nnoremap gV `[v`]

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
augroup END

" Elm
augroup file_elm
    au!
    au BufNewFile,BufRead *.elm set tabstop=4
    au BufNewFile,BufRead *.elm set softtabstop=4
    au BufNewFile,BufRead *.elm set shiftwidth=4
augroup END

"""""""""""""""""""""""""""""""""""""""""""""""
"              Plugin Settings                "
"""""""""""""""""""""""""""""""""""""""""""""""
" ag
" highlight
let g:ag_highlight=1
let g:ag_working_path_mode="r"

" Command-T
"" ignore search
let g:CommandTWildIgnore=&wildignore . "*/bower_components,*/node_modules,*/.git,*/__pycache__,*/elm-stuff"

" Emmet
"" Enable Only in Insert Mode
let g:user_emmet_mode='i'
"" Enable only for html, css
let g:user_emmet_install_global = 0
autocmd BufNewFile,BufRead *.hbs set filetype=handlebars " enable emmet for handlebars
autocmd FileType xhtml,html,handlebars,css,less,sass,scss EmmetInstall
"" Redefine trigger key
let g:user_emmet_leader_key=','

" Netrw
let g:netrw_liststyle=0
let g:netrw_keepdir= 0

" delimitMate
let delimitMate_expand_cr = 1
let delimitMate_expand_space = 1
let delimitMate_jump_expansion = 1

" elm-vim
let g:elm_setup_keybindings = 0

" YouCompleteMe
" Debug
" let g:ycm_server_keep_logfiles = 1
" let g:ycm_server_log_level = 'debug'
""  Python3 Semantic Completion
let g:ycm_python_binary_path = '/usr/bin/python3'
""  Rust Semantic Completion
let g:ycm_rust_src_path = '/usr/src/rust/src'
"" Go To Definition
nnoremap <leader>gd  :YcmCompleter GoTo<CR>
"" Autoclose Preview Window when leaves insert mode
let g:ycm_autoclose_preview_window_after_insertion = 1
" elm support
let g:ycm_semantic_triggers = {
     \ 'elm' : ['.'],
     \}

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
    au Filetype * :iabbrev <buffer> re; return
augroup END

augroup javascript_snippets
    au!
    au Filetype javascript :iabbrev <buffer> fn;   function
    au Filetype javascript :iabbrev <buffer> log;  console.log(
    au Filetype javascript :iabbrev <buffer> con;  constructor
    " React Js
    au Filetype javascript :iabbrev <buffer> Rr;   render() {
    au Filetype javascript :iabbrev <buffer> Rgis; getInitialState() {
    au Filetype javascript :iabbrev <buffer> Rgdp; getDefaultProps() {
    au Filetype javascript :iabbrev <buffer> Rpt;  propTypes
    au Filetype javascript :iabbrev <buffer> Rcwm; componentWillMount() {
    au Filetype javascript :iabbrev <buffer> Rcdm; componentDidMount() {
    au Filetype javascript :iabbrev <buffer> Rwrp; componentWillReceiveProps( nextProps ) {
    au Filetype javascript :iabbrev <buffer> Rscu; shouldComponentUpdate( nextProps, nextState ) {
    au Filetype javascript :iabbrev <buffer> Rcwu; componentWillUpdate( nextProps, nextState ) {
    au Filetype javascript :iabbrev <buffer> Rcdu; componentDidUpdate( prevProps, prevState ) {
    au Filetype javascript :iabbrev <buffer> Rwun; componentWillUnmount() {
    au Filetype javascript :iabbrev <buffer> Rpa;  PropTypes.array
    au Filetype javascript :iabbrev <buffer> Rpar; PropTypes.array.isRequired
    au Filetype javascript :iabbrev <buffer> Rpb;  PropTypes.bool
    au Filetype javascript :iabbrev <buffer> Rpbr; PropTypes.bool.isRequired
    au Filetype javascript :iabbrev <buffer> Rpf;  PropTypes.func
    au Filetype javascript :iabbrev <buffer> Rpfr; PropTypes.func.isRequired
    au Filetype javascript :iabbrev <buffer> Rpn;  PropTypes.number
    au Filetype javascript :iabbrev <buffer> Rpnr; PropTypes.number.isRequired
    au Filetype javascript :iabbrev <buffer> Rpo;  PropTypes.object
    au Filetype javascript :iabbrev <buffer> Rpor; PropTypes.object.isRequired
    au Filetype javascript :iabbrev <buffer> Rps;  PropTypes.string
    au Filetype javascript :iabbrev <buffer> Rpsr; PropTypes.string.isRequired
augroup END

