"
" Python filetype plugin for running flake8
" Language:     Python (ft=python)
" Maintainer:   Vincent Driessen <vincent@3rdcloud.com>
" Version:      Vim 7 (may work with lower Vim versions, but not tested)
" URL:          http://github.com/nvie/vim-flake8
"
" Only do this when not done yet for this buffer
if exists("b:loaded_flake8_ftplugin")
    finish
endif
let b:loaded_flake8_ftplugin=1

if !exists("*Flake8()")
    function Flake8()
        if exists("g:flake8_cmd")
            let s:flake8_cmd=g:flake8_cmd
        else
            let s:flake8_cmd="flake8"
        endif

        if !executable(s:flake8_cmd)
            echoerr "File " . s:flake8_cmd . " not found. Please install it first."
            return
        endif

        set lazyredraw   " delay redrawing
        cclose           " close any existing cwindows

        " store old grep settings (to restore later)
        let l:old_gfm=&grepformat
        let l:old_gp=&grepprg

        " write any changes before continuing
        if &readonly == 0
            update
        endif

        " read config
        if exists("g:flake8_builtins")
            let s:flake8_builtins_opt=" --builtins=".g:flake8_builtins
        else
            let s:flake8_builtins_opt=""
        endif

        if exists("g:flake8_ignore")
            let s:flake8_ignores=" --ignore=".g:flake8_ignore
        else
            let s:flake8_ignores=""
        endif

        if exists("g:flake8_max_line_length")
            let s:flake8_max_line_length=" --max-line-length=".g:flake8_max_line_length
        else
            let s:flake8_max_line_length=""
        endif

        if exists("g:flake8_max_complexity")
            let s:flake8_max_complexity=" --max-complexity=".g:flake8_max_complexity
        else
            let s:flake8_max_complexity=""
        endif

        " perform the grep itself
        let &grepformat="%f:%l:%c: %m\,%f:%l: %m"
        let &grepprg=s:flake8_cmd.s:flake8_builtins_opt.s:flake8_ignores.s:flake8_max_line_length.s:flake8_max_complexity
        silent! grep! %

        " restore grep settings
        let &grepformat=l:old_gfm
        let &grepprg=l:old_gp

        " open cwindow
        let has_results=getqflist() != []
        if has_results
            execute 'belowright copen'
            setlocal wrap
            nnoremap <buffer> <silent> c :cclose<CR>
            nnoremap <buffer> <silent> q :cclose<CR>
        endif

        set nolazyredraw
        redraw!

        if has_results == 0
            " Show OK status
            hi Green ctermfg=green
            echohl Green
            echon "Flake8 check OK"
            echohl
        endif
    endfunction
endif

" Add mappings, unless the user didn't want this.
" The default mapping is registered under to <F7> by default, unless the user
" remapped it already (or a mapping exists already for <F7>)
if !exists("no_plugin_maps") && !exists("no_flake8_maps")
    if !hasmapto('Flake8(')
        noremap <buffer> <F7> :call Flake8()<CR>
    endif
endif
