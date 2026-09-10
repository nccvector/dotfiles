call plug#begin()

Plug 'liuchengxu/vim-which-key'
Plug 'morhetz/gruvbox'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

call plug#end()

" Setting preferences
set timeoutlen=33
set background=dark
set scrolloff=10
colorscheme gruvbox
set number
set hlsearch
set incsearch
set ignorecase
set splitright
set splitbelow

" Setting <space> as leader
let g:mapleader = "\<Space>"
let g:maplocalleader = ','

" Configuring which-key
nnoremap <silent> <leader> :<c-u>WhichKey '<Space>'<CR>
vnoremap <silent> <leader> :<c-u>WhichKeyVisual '<Space>'<CR>

" Register keymaps
call which_key#register('<Space>', "g:which_key_map")

" Define prefix dictionary
let g:which_key_map =  {}

" Second level dictionaries:
" 'name' is a special field. It will define the name of the group, e.g., leader-f is the "+file" group.
" Unnamed groups will show a default empty string.

" =======================================================
" Create menus based on existing mappings
" =======================================================
" You can pass a descriptive text to an existing mapping.

let g:which_key_map.f = { 'name' : '+file' }

nnoremap <silent> <leader>fs :update<CR>
let g:which_key_map.f.s = 'Save'

" :Files comes from fzf vim plugin
nnoremap <silent> <leader>ff :Files<CR>
let g:which_key_map.f.f = 'Find'

nnoremap <silent> <leader>oq  :copen<CR>
nnoremap <silent> <leader>ol  :lopen<CR>
let g:which_key_map.o = {
      \ 'name' : '+open',
      \ 'q' : 'open-quickfix',
      \ 'l' : 'open-locationlist',
      \ }

" =======================================================
" Create menus not based on existing mappings:
" =======================================================
" Provide commands(ex-command, <Plug>/<C-W>/<C-d> mapping, etc.)
" and descriptions for the existing mappings.
"
" Note:
" Some complicated ex-cmd may not work as expected since they'll be
" feed into `feedkeys()`, in which case you have to define a decicated
" Command or function wrapper to make it work with vim-which-key.
" Ref issue #126, #133 etc.
let g:which_key_map.b = {
      \ 'name' : '+buffer' ,
      \ '1' : ['b1'        , 'buffer 1'],
      \ '2' : ['b2'        , 'buffer 2'],
      \ 'd' : ['bd'        , 'delete-buffer'],
      \ 'b' : [':Buffers'  , 'delete-buffer'],
      \ 'f' : ['bfirst'    , 'first-buffer'],
      \ 'h' : ['Startify'  , 'home-buffer'],
      \ 'l' : ['blast'     , 'last-buffer'],
      \ 'n' : ['bnext'     , 'next-buffer'],
      \ 'p' : ['bprevious' , 'previous-buffer'],
      \ '?' : ['Buffers'   , 'fzf-buffer'],
      \ }

let g:which_key_map.w = {
      \ 'name' : '+window' ,
      \ 'q' : ['<C-w>q'     , 'Close'],
      \ 'h' : ['<C-w>h'  , 'Jump left'],
      \ 'j' : ['<C-w>j'  , 'Jump down'],
      \ 'k' : ['<C-w>k'  , 'Jump up'],
      \ 'l' : ['<C-w>l'     , 'Jump right'],
      \ 's' : ['<C-w>s'     , 'Split horizontal'],
      \ 'v' : ['<C-w>v'     , 'Split vertical'],
      \ 'd' : ['<C-w>q'     , 'Close'],
      \ }

let g:which_key_map.c = {
      \ 'name' : '+config' ,
      \ 's' : [':source ~/.vimrc'  , 'Source'],
      \ }

nnoremap <silent> <leader>q :q<CR>
let g:which_key_map.q = 'Close buffer'
