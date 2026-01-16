
" =========================
" 基本：本機覆寫（先載入）
" =========================
if filereadable(expand('~/.vimrc.local'))
  source ~/.vimrc.local
endif

" 減少延遲感
set updatetime=300
set timeoutlen=500

" =========================
" 介面 / 編輯體驗
" =========================
set number
set cursorline
set showcmd
set showmatch
set signcolumn=yes

" 分割偏好（新垂直分割在右，新水平分割在下）
set splitright
set splitbelow

" Tab 與縮排（你的設定）
set tabstop=4
set shiftwidth=4
set expandtab
filetype plugin indent on
syntax on

" 搜尋（你的設定）
set smartcase
set hlsearch
set incsearch

" 滑鼠（想保持純鍵盤可註解掉）
set mouse=a

" 系統剪貼簿（你的設定，環境支援時啟用）
if has('clipboard')
  set clipboard=unnamedplus
endif

" 命令列與補全
set wildmenu
set wildmode=longest:full,full

" 顯示不可見字元（預設關閉，如需再開）
set listchars=tab:»\ ,trail:·,extends:›,precedes:‹
" set list

" =========================
" 檔案 / 備份 / Undo
" =========================
" 使用持久 Undo 與獨立目錄管理暫存
if has('persistent_undo')
  set undofile
  set undodir=~/.vim/undo
endif
set backup
set backupdir=~/.vim/backup
set directory=~/.vim/swap

" 啟動時確保目錄存在
augroup vim_bootstrap_dirs
  autocmd!
  autocmd VimEnter * call s:EnsureDirs()
augroup END

function! s:EnsureDirs() abort
  for d in ['~/.vim/undo', '~/.vim/backup', '~/.vim/swap', '~/.vim/autoload', '~/.vim/plugged']
    if !isdirectory(expand(d))
      call mkdir(expand(d), 'p')
    endif
  endfor
endfunction

" =========================
" Leader 與常用快捷
" =========================
let mapleader = " "

" 儲存／離開／取消搜尋高亮
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>/ :nohlsearch<CR>

" =========================
" 自動安裝 vim-plug（無需手動）
" =========================
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * ++once PlugInstall --sync | source $MYVIMRC
endif

" =========================
" Plugins（vim-plug）
" =========================
call plug#begin('~/.vim/plugged')

" === 你原本的外掛 ===
Plug 'preservim/nerdtree'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'vim-airline/vim-airline'

" === 建議但非必要（可取消註解啟用） ===
" Plug 'tpope/vim-fugitive'        " Git 超好用
" Plug 'airblade/vim-gitgutter'    " 顯示 Git diff 標記
" Plug 'morhetz/gruvbox'           " 主題（或選擇你喜歡的配色）
" Plug 'jiangmiao/auto-pairs'      " 括號自動補全（若你不靠 LSP）

call plug#end()

" =========================
" Plugin 設定與快捷
" =========================

" --- Airline ---
set laststatus=2
let g:airline#extensions#tabline#enabled = 1
" 若字型支援 powerline 符號可開啟
" let g:airline_powerline_fonts = 1

" --- NERDTree ---
let g:NERDTreeShowHidden = 1
let g:NERDTreeQuitOnOpen = 1
nnoremap <leader>e :NERDTreeToggle<CR>

" --- FZF ---
" 使用 ripgrep 作為預設搜尋（若存在）；否則 fallback
if executable('rg')
  let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow --glob "!.git/*"'
  command! -nargs=* Rg call fzf#vim#grep(
        \ 'rg --column --line-number --no-heading --color=always --smart-case --hidden --glob "!.git/*" '.shellescape(<q-args>),
        \ 1, fzf#vim#with_preview(), 0)
elseif executable('fd')
  let $FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
endif
nnoremap <leader>ff :Files<CR>
nnoremap <leader>fg :Rg<Space>

" =========================
" 顏色主題（可依喜好調整）
" =========================
set background=dark
" colorscheme gruvbox " 若有安裝主題，取消註解

" =========================
" 針對本機的再次客製
" =========================
" 你如果希望「本機設定蓋過通用設定」，把以下一行移到檔案最底
" if filereadable(expand('~/.vimrc.local')) | source ~/.vimrc.local | endif

