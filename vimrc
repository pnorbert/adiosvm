" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

" allow backspacing over everything in insert mode
set backspace=indent,eol,start

set autoindent
set cindent
" use space instead of TABs, 4 spaces each
set shiftwidth=4
set softtabstop=4
set expandtab
" for Makefiles, use real tab characters
"autocmd FileType make setlocal noexpandtab
" remap Shift+Tab to insert real TAB character
inoremap <S-Tab> <C-V><Tab>


" statusline that displays the current cursor position
set ruler

" briefly jump to a brace/parenthese/bracket's match 
"   whenever you type a closing or opening brace/parenthese/bracket
set showmatch

" syntax highlighting
syntax enable

" Search options
" --------------
" case insensitive search for small-case strings
set ignorecase
" but case sensitive search if capitals are given in the search string
set smartcase
" highlight all occurences of the searched string
set hlsearch
" jump to first occurence when typing a search string
set incsearch

" remember positions in files and jump there when opening again
if has("autocmd")
    autocmd BufReadPost * 
    \ if line("'\"") > 0 && line("'\"") <= line("$") | 
    \ exe "normal g`\"" | 
    \ endif 
endif
