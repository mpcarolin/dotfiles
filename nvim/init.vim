set fileformat=unix

" add .vim directory to runtime path (needed for "plug")
set rtp +=~/.vim

" =============================== Plugins ===============================
call plug#begin()

Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'gwww/vim-bbye'
Plug 'diepm/vim-rest-console'
Plug 'moll/vim-node'
Plug 'vimwiki/vimwiki'
Plug 'editorconfig/editorconfig-vim'
Plug 'mhinz/vim-startify'
Plug 'karb94/neoscroll.nvim'
Plug 'rizzatti/dash.vim'
Plug 'stephpy/vim-yaml'
Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'morhetz/gruvbox'
Plug 'sainnhe/everforest'
Plug 'arcticicestudio/nord-vim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'scrooloose/nerdtree'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rails'
Plug 'vim-ruby/vim-ruby'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'Mofiqul/dracula.nvim'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'jiangmiao/auto-pairs'
Plug 'maksimr/vim-jsbeautify'
Plug 'vim-test/vim-test'
Plug 'xolox/vim-misc'
Plug 'preservim/nerdcommenter'
Plug 'airblade/vim-gitgutter'
Plug 'michaeldyrynda/carbon'
Plug 'christoomey/vim-tmux-navigator'
Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app && yarn install'  }
Plug 'w0rp/ale'

call plug#end()

filetype plugin on

" ============================= KeyBindings =============================

" Use K to show documentation in preview window.
function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction
nnoremap <silent> K :call ShowDocumentation()<CR>

" ----> Go to last file
nnoremap <C-;> :e#<Cr>

" ----> VimWiki
let g:vimwiki_list = [{'path': '~/vimwiki/', 'syntax': 'markdown', 'ext': '.md'}]
let g:vimwiki_ext2syntax = { '.md': 'markdown' }
let g:vimwiki_key_mappings = { 'all_maps': 0, }
nmap <Leader>l <Plug>:VimwikiToggleListItem
vmap <Leader>l <Plug>:VimwikiToggleListItem
nnoremap <Leader>vw <Plug>VimwikiIndex

" ----> EditorConfig
let g:EditorConfig_exclude_patterns = ['fugitive://.*']
au FileType gitcommit let b:EditorConfig_disable = 1

" ----> CoC
" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
nnoremap <leader>o  :call ToggleOutline()<CR>
function! ToggleOutline() abort
  let winid = coc#window#find('cocViewId', 'OUTLINE')
  if winid == -1
    call CocActionAsync('showOutline', 1)
  else
    call coc#window#close(winid)
  endif
endfunction
" Run the Code Lens action on the current line.
nmap <leader>cl  <Plug>(coc-codelens-action)

" ----> NERDTree
let g:NERDTreeDirArrowExpandable = '▸'
let g:NERDTreeDirArrowCollapsible = '▾'

" ctrl+t toggle for nerdtree
nnoremap <C-t> :NERDTreeToggle<CR>
nnoremap <C-a> :NERDTreeFind<CR>

" ----> FZF (Fuzzy File Search)
nnoremap <C-p> :GFiles<Cr>
nnoremap <C-m> :Marks<Cr>
nnoremap <C-n> :Files<Cr>
nnoremap <C-b> :Buffers<Cr>


" ----> QuickFix
nnoremap <Leader>q :copen<CR>

" Tabs
" this character maps to "option+h" on MacOS
nnoremap ˙ :bprev<CR>
" this character maps to "option+l" on MacOS
nnoremap ¬ :bnext<CR>

" markdown
nnoremap <Leader>mp :MarkdownPreview<CR>
nnoremap <Leader>mps :MarkdownPreviewStop<CR>
let g:mkdp_filetypes = ['markdown', 'vimwiki']

" quickfix navigation
nnoremap <Leader>co :copen<CR>
nnoremap <Leader>cn :cnext<CR>
nnoremap <Leader>cp :cprev<CR>

" common leader mappings
let g:mapleader = " "

" switch to previous buffer
nnoremap <Leader><Leader> <C-^>

" close pane
nnoremap <Leader>w :close<CR>

" close current buffer
nnoremap <Leader>dd :Bdelete<CR>

" close all buffers
nnoremap <Leader>da :bufdo :Bdelete<CR>

" close other buffers
command! BufCurOnly execute '%bdelete|edit#|bdelete#'
nnoremap <Leader>do :BufCurOnly<CR>

" save and source current file
nnoremap <Leader>so :w \| :source %<CR>

" source nvim init
nnoremap <Leader>sov :source ~/.config/nvim/init.vim<CR>

" rotate between relative, regular, or no line numbers
nnoremap <Leader>i :set invnumber<CR>

" tests
nmap <Leader>t :w \| :TestFile<CR>
nmap <Leader>tl :TestLast<CR>
nmap <Leader>ts :TestSuite<CR>

" Git
nnoremap <Leader>gg :Git<CR>
nnoremap <Leader>gc :Git commit<CR>
nnoremap <Leader>gp :Git push<CR>

nnoremap <Leader>gv :Gvdiffsplit
" > history of last 100 commits
nnoremap <Leader>gl :Gclog -100<CR>
" > commit history of current file
nnoremap <Leader>gf :0Gclog -100<CR>

" ale linter
nnoremap <Leader>ll :ALELint<CR>

" terminal
tnoremap <Esc> <C-\><C-n>

" mapping to enable indent folding
nnoremap <Leader>ef :set foldmethod=indent<CR>
nnoremap <Leader>fe :set nofoldenable<CR>

nnoremap <Leader>s :Ggrep -q 

" Yank full path to current buffer
nnoremap <Leader>yf :let @" = expand("%")<CR>

" Yank visual selection to OS clipboard
vnoremap <Leader>yc "*y

" Execute buffer
nnoremap <Leader>xn :!node %<CR>
nnoremap <Leader>xb :!bash %<CR>
nnoremap <Leader>xx :!./%<CR>

" ============================ Vim-Session ==============================
let g:session_autosave = "yes"

" ============================== Vim-Test ===============================
let test#strategy = "neovim"
let test#neovim#term_position = "bot"

" ============================ Vim-Airlines =============================
let g:airline_theme="everforest"
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1

" ============================= Ale Linter ==============================
let g:ale_fixers = {
 \ 'javascript': ['eslint']
 \ }

let g:ale_sign_error = 'X'
let g:ale_sign_warning = '⚠️'

let g:ale_fix_on_save = 0

" ============================= NeoScroll ==============================
lua << EOF
require('neoscroll').setup({
    -- All these keys will be mapped to their corresponding default scrolling animation
    mappings = {'<C-u>', '<C-d>', '<C-y>', '<C-e>', 'zt', 'zz', 'zb'},
    hide_cursor = true,          -- Hide cursor while scrolling
    stop_eof = true,             -- Stop at <EOF> when scrolling downwards
    use_local_scrolloff = false, -- Use the local scope of scrolloff instead of the global scope
    respect_scrolloff = false,   -- Stop scrolling when the cursor reaches the scrolloff margin of the file
    cursor_scrolls_alone = true, -- The cursor will keep on scrolling even if the window cannot scroll further
})
EOF
" ========================== General Settings ===========================
"
"
" ==== EVERFOREST 
" Important!!
if has('termguicolors')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif

" For dark version.
set background=dark

" For light version.
"set background=light

" Set contrast.
" This configuration option should be placed before `colorscheme everforest`.
" Available values: 'hard', 'medium'(default), 'soft'
let g:everforest_background = 'hard'

" For better performance
let g:everforest_better_performance = 1

colorscheme everforest
" ==== /EVERFOREST

" this instructs vim to ignore the terminal app's colorscheme and use settings
" meant for the GUI version of Vim instead, which use 24-bit colors. Don't
" enable this if your theme requires the same theme from the terminal (like
" Nord theme)
"set termguicolors

set relativenumber

filetype plugin indent on

" On pressing tab, insert 2 spaces
set expandtab

"show existing tab with 2 spaces width
set tabstop=2
set softtabstop=2

" when indenting with '>', use 2 spaces width
set shiftwidth=2

" highlight current line
set cursorline

" new vertical splits are on the right
set splitright

map <C-f> :call RangeJsBeautify()<cr>

" leading spaces and tabs visualized
set list lcs=lead:·,trail:·,tab:»·

" highlight yanked results for 500ms
augroup highlight_yank
augroup END

" vim wiki required settings
syntax on
set nocompatible

