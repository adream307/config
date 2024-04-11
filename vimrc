set nocompatible
set backspace=indent,eol,start
set number
set nowrap
set updatetime=100
"set mouse=a       " Enable mouse (esp. for balloons and scrolling in popups)
"set ttymouse=sgr  " .. also in 'terminals that emit SGR-styled mouse reporting'

set foldmethod=indent
set foldlevel=99
"set foldopen=all

syntax on

"" autocmd
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

set expandtab
set tabstop=4
set shiftwidth=4
"auto reload file if it change on disk
set autoread
au CursorHold * checktime

set ignorecase
set smartcase

set nobackup
set nowb
set noswapfile
colorscheme darkblue


"" example of use grep vim
"" 1. grep {pattern} in git files                   -> :vimgrep {pattern} `git ls-files`
"" 2. open quickfix-list to navigate the result     -> :copen
let Grep_Skip_Dirs = 'RCS CVS SCCS .svn .git generated'
set grepprg=/bin/grep\ -nH
nnoremap gn :cn<CR>
nnoremap gp :cp<CR>

" Resize split 
nnoremap <S-J>  :res +5<CR>
nnoremap <S-K>  :res -5<CR>
nnoremap <S-H>  :vertical resize -5<CR>
nnoremap <S-L>  :vertical resize +5<CR>

" set encoding
autocmd FileType c,cpp,objc set colorcolumn=120
autocmd FileType c,cpp,objc highlight ColorColumn ctermbg=darkgray
set encoding=utf-8
set termencoding=utf-8
set fileencoding=utf-8

nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>
"nnoremap <C-W> <C-W><C-W>

tnoremap <C-J> <C-W><C-J>
tnoremap <C-K> <C-W><C-K>
tnoremap <C-L> <C-W><C-L>
tnoremap <C-H> <C-W><C-H>
tnoremap <ESC><ESC> <C-\><C-n>

"nnoremap <C-H> <C-W><C-W>
"nnoremap <C-U> :tabn<cr>

nnoremap <f5> :tabp<cr>
nnoremap <f6> :tabn<cr>
nnoremap <f7> :tabnew %<cr>

nnoremap <expr>s col(".")==1?"$":"0"

" page down and page up
"nnoremap <C-J> <C-D>
"nnoremap <C-K> <C-U>

" highlight search
set hlsearch
set incsearch
nnoremap gfn :nohl<CR>
"inoremap gfn :nohl<CR>a

"copy to system clipboard
noremap <Leader>y  "+y
noremap <Leader>yw "+yiw
noremap <Leader>yy "+yy
noremap <Leader>p  "+p

"copy word to buffer
nnoremap yw yiw
nnoremap wp viw"0p
nnoremap dw diw

"" yank text in normal mode and paste in commnad line
"" <C-R>"

"copy file name to system clipboard
",cs -> just copy file name
",cl -> copy filen name with path
nmap ,cs :let @+=expand("%")<CR>
nmap ,cl :let @+=expand("%:p")<CR>

"search select
vnoremap gff y/\V<C-R>=escape(@",'/\')<CR><CR>
nnoremap gff yiw/\V<C-R>=escape(@",'/\')<CR><CR>

nnoremap <space> :
vnoremap <space> :
"inoremap jj <esc>
"cnoremap jj <c-c><esc>

set undofile
if !isdirectory($HOME."/.vim/undodir")
    call mkdir($HOME."/.vim/undodir","p")
endif
set undodir =$HOME."/.vim/undodir"

set splitright
let g:termdebug_wide=1
packadd termdebug

command! -nargs=0 Bash vert term zsh

call plug#begin('~/.vim/plugged')

" clang-format
Plug 'rhysd/vim-clang-format'

" git
Plug 'tpope/vim-fugitive'

Plug 'preservim/nerdtree'

" lsp
Plug 'prabirshrestha/vim-lsp'
Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-lsp.vim'

" Jump
Plug 'Yggdroot/LeaderF', {'do': ':LeaderfInstallCExtension'}

" vim proc
"Plug 'Shougo/vimproc.vim', {'do' : 'make'}
"Plug 'shougo/vimshell.vim'

" Auto Pair
Plug 'jiangmiao/auto-pairs'

call plug#end()

"clang-format
"let g:clang_format#command = $HOME."/bin/clang-format"
autocmd FileType c,cpp,objc nnoremap <buffer><Leader>cf :<C-u>ClangFormat<CR>
autocmd FileType c,cpp,objc vnoremap <buffer><Leader>cf :ClangFormat<CR>
autocmd FileType c,cpp,objc ClangFormatAutoEnable 
let g:clang_format#detect_style_file = 1

let g:Lf_ShowDevIcons = 0

"let g:Lf_HideHelp = 1
let g:Lf_UseCache = 0
let g:Lf_UseVersionControlTool = 0
let g:Lf_IgnoreCurrentBufferName = 1
" popup mode
let g:Lf_WindowPosition = 'popup'
let g:Lf_PreviewInPopup = 1
let g:Lf_StlSeparator = { 'left': "\ue0b0", 'right': "\ue0b2", 'font': "DejaVu Sans Mono for Powerline" }
let g:Lf_PreviewResult = {'Function': 0, 'BufTag': 0 }

let g:Lf_ShortcutF = "<leader>ff"

noremap mm :<C-U><C-R>=printf("Leaderf mru %s", "")<CR><CR>
noremap ff :<C-U><C-R>=printf("Leaderf file")<CR><CR>
noremap gl :<C-U><C-R>=printf("Leaderf line %s", "")<CR><CR>
noremap <leader>fb :<C-U><C-R>=printf("Leaderf buffer %s", "")<CR><CR>
noremap <leader>fm :<C-U><C-R>=printf("Leaderf mru %s", "")<CR><CR>
noremap <leader>ft :<C-U><C-R>=printf("Leaderf bufTag %s", "")<CR><CR>
noremap <leader>fl :<C-U><C-R>=printf("Leaderf line %s", "")<CR><CR>
noremap <leader>fh :Leaderf rg 
noremap <leader>fr :Leaderf --recall<CR> 

nmap <f2> :NERDTreeToggle<cr>
let NERDTreeMapUpdir='\u'
let NERDTreeMapUpdirKeepOpen='\U'
let NERDTreeMapChangeRoot='\c'

"" lsp
"ref : https://jdhao.github.io/2020/11/05/pyls_flake8_setup/
"if executable('pyls')
"    " pip install python-language-server
"    au User lsp_setup call lsp#register_server({
"        \ 'name': 'pyls',
"        \ 'cmd': {server_info->['pyls']},
"        \ 'allowlist': ['python'],
"        \ 'workspace_config': {
"        \    'pyls':
"        \        {'configurationSources': ['flake8'],
"        \         'plugins': {'flake8': {'enabled': v:true},
"        \                     'pyflakes': {'enabled': v:false},
"        \                     'pycodestyle': {'enabled': v:false},
"        \                    }
"        \         }
"        \ }})
"endif

if executable('pyright-langserver')
    au User lsp_setup call lsp#register_server({
       \ 'name': 'pyright-langserver',
       \ 'cmd': {server_info->['pyright-langserver','--stdio']},
       \ 'allowlist': ['python'],
       \ 'root_uri': {server_info->lsp#utils#path_to_uri(lsp#utils#find_nearest_parent_file_directory(lsp#utils#get_buffer_path(), '.root'))},
       \ 'initialization_options': v:null,
       \ 'workspace_config':{
       \    'python': {
       \        'analysis': {
       \            'useLibraryCodeForTypes': v:true
       \        },
       \    },
       \ }})
endif

if executable('bash-language-server')
  au User lsp_setup call lsp#register_server({
       \ 'name': 'bash-language-server',
       \ 'cmd': {server_info->[&shell, &shellcmdflag, 'bash-language-server start']},
       \ 'allowlist': ['sh'],
       \ })
endif

if executable('gopls')
  au User lsp_setup call lsp#register_server({
      \ 'name': 'go-lang',
      \ 'cmd': {server_info->['gopls']},
      \ 'whitelist': ['go'],
      \ })
  "autocmd FileType go setlocal omnifunc=lsp#complete
  "autocmd FileType go nmap <buffer> gd <plug>(lsp-definition)
  "autocmd FileType go nmap <buffer> ,n <plug>(lsp-next-error)
  "autocmd FileType go nmap <buffer> ,p <plug>(lsp-previous-error)
endif

" Register ccls C++ lanuage server.
if executable('ccls')
   au User lsp_setup call lsp#register_server({
      \ 'name': 'ccls',
      \ 'cmd': {server_info->['ccls']},
      \ 'root_uri': {server_info->lsp#utils#path_to_uri(lsp#utils#find_nearest_parent_file_directory(lsp#utils#get_buffer_path(), 'compile_commands.json'))},
      \ 'initialization_options': {'cache': {'directory': expand('~/.cache/ccls') }, "index": {"threads": 12}},
      \ 'allowlist': ['c', 'cpp', 'objc', 'objcpp', 'cc', 'cu'],
      \ })
endif

function! s:on_lsp_buffer_enabled() abort
    setlocal omnifunc=lsp#complete
    setlocal signcolumn=yes
    if exists('+tagfunc') | setlocal tagfunc=lsp#tagfunc | endif
    " go back to origin buffer
    nmap <buffer> ga <c-o>
    nmap <buffer> gb <c-i>
    nmap <buffer> gd <plug>(lsp-definition)
    nmap <buffer> gs <plug>(lsp-document-symbol-search)
    nmap <buffer> gh <plug>(lsp-workspace-symbol-search)
    nmap <buffer> gr <plug>(lsp-references)
    nmap <buffer> gi <plug>(lsp-implementation)
    nmap <buffer> gt <plug>(lsp-type-definition)
    nmap <buffer> <leader>rn <plug>(lsp-rename)
    nmap <buffer> [g <plug>(lsp-previous-diagnostic)
    nmap <buffer> ]g <plug>(lsp-next-diagnostic)
    nmap <buffer> gk <plug>(lsp-hover)
    nnoremap <buffer> <expr><c-f> lsp#scroll(+4)
    nnoremap <buffer> <expr><c-d> lsp#scroll(-4)

    let g:lsp_format_sync_timeout = 1000
    autocmd! BufWritePre *.rs,*.go call execute('LspDocumentFormatSync')
    "let g:lsp_log_verbose = 1
    "let g:lsp_log_file = expand('~/vim-lsp.log')

    " refer to doc to add more commands
endfunction

augroup lsp_install
    au!
    " call s:on_lsp_buffer_enabled only for languages that has the server registered.
    autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END
let g:lsp_diagnostics_echo_cursor = 1

"inoremap <expr> <cr> pumvisible() ? asyncomplete#close_popup() . "\<cr>" : "\<cr>"
inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <expr> <cr>    pumvisible() ? asyncomplete#close_popup() : "\<cr>"

"gdb debug
command! -nargs=* DebugT TermdebugCommand t <args>
