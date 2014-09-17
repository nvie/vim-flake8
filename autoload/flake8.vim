"
" Python filetype plugin for running flake8
" Language:     Python (ft=python)
" Maintainer:   Vincent Driessen <vincent@3rdcloud.com>
" Version:      Vim 7 (may work with lower Vim versions, but not tested)
" URL:          http://github.com/nvie/vim-flake8

let s:save_cpo = &cpo
set cpo&vim

"" ** external ** {{{

function! flake8#Flake8()
    call s:Flake8()
endfunction

function! flake8#Flake8UnplaceMarkers()
    call s:UnplaceMarkers()
endfunction

"" }}}

"" ** internal ** {{{

"" config

function! s:DeclareOption(name, globalPrefix, default)  " {{{
    if !exists('g:'.a:name)
        execute 'let s:'.a:name.'='.a:default
    else
        execute 'let s:'.a:name.'="'.a:globalPrefix.'".g:'.a:name
    endif
endfunction  " }}}

function! s:SetupConfig()  " {{{
    "" read options

    " flake8 command
    call s:DeclareOption('flake8_cmd', '', '"flake8"')
    " flake8 stuff
    call s:DeclareOption('flake8_builtins',        ' --builtins=',        '')
    call s:DeclareOption('flake8_ignore',          ' --ignore=',          '')
    call s:DeclareOption('flake8_max_line_length', ' --max-line-length=', '')
    call s:DeclareOption('flake8_max_complexity',  ' --max-complexity=',  '')
    " quickfix
    call s:DeclareOption('flake8_quickfix_location', '', '"belowright"')
    call s:DeclareOption('flake8_show_quickfix',     '', 1)
    " markers to show
    call s:DeclareOption('flake8_show_in_gutter', '',   0)
    call s:DeclareOption('flake8_show_in_file',   '',   0)
    call s:DeclareOption('flake8_max_markers',    '', 500)
    " marker signs
    call s:DeclareOption('flake8_error_marker',      '', '"E>"')
    call s:DeclareOption('flake8_warning_marker',    '', '"W>"')
    call s:DeclareOption('flake8_pyflake_marker',    '', '"F>"')
    call s:DeclareOption('flake8_complexity_marker', '', '"C>"')
    call s:DeclareOption('flake8_naming_marker',     '', '"N>"')

    "" setup markerdata

    let s:markerdata = {}
    if s:flake8_error_marker != ''
    let s:markerdata['E'] = {
                    \   'color':  'Flake8_Error',
                    \   'marker': s:flake8_error_marker,
                    \   'sign':   'Flake8_E',
                    \ }
    endif
    if s:flake8_warning_marker != ''
        let s:markerdata['W'] = {
                    \   'color':  'Flake8_Warning',
                    \   'marker': s:flake8_warning_marker,
                    \   'sign':   'Flake8_W',
                    \ }
    endif
    if s:flake8_pyflake_marker != ''
        let s:markerdata['F'] = {
                    \   'color':  'Flake8_PyFlake',
                    \   'marker': s:flake8_pyflake_marker,
                    \   'sign':   'Flake8_F',
                    \ }
    endif
    if s:flake8_complexity_marker != ''
        let s:markerdata['C'] = {
                    \   'color':  'Flake8_Complexity',
                    \   'marker': s:flake8_complexity_marker,
                    \   'sign':   'Flake8_C',
                    \ }
    endif
    if s:flake8_naming_marker != ''
        let s:markerdata['N'] = {
                    \   'color':  'Flake8_Nameing',
                    \   'marker': s:flake8_naming_marker,
                    \   'sign':   'Flake8_N',
                    \ }
    endif
endfunction  " }}}

"" do flake8

function! s:Flake8()  " {{{
    " read config
    call s:SetupConfig()

    if !executable(s:flake8_cmd)
        echoerr "File " . s:flake8_cmd . " not found. Please install it first."
        return
    endif

    " store old grep settings (to restore later)
    let l:old_gfm=&grepformat
    let l:old_gp=&grepprg
    let l:old_shellpipe=&shellpipe

    " write any changes before continuing
    if &readonly == 0
        update
    endif

    set lazyredraw   " delay redrawing
    cclose           " close any existing cwindows

    " set shellpipe to > instead of tee (suppressing output)
    set shellpipe=>

    " perform the grep itself
    let &grepformat="%f:%l:%c: %m\,%f:%l: %m"
    let &grepprg=s:flake8_cmd.s:flake8_builtins.s:flake8_ignore.s:flake8_max_line_length.s:flake8_max_complexity
    silent! grep! "%"

    echo s:flake8_cmd.s:flake8_builtins.s:flake8_ignore.s:flake8_max_line_length.s:flake8_max_complexity

    " restore grep settings
    let &grepformat=l:old_gfm
    let &grepprg=l:old_gp
    let &shellpipe=l:old_shellpipe

    " process results
    let l:results=getqflist()
    let l:has_results=results != []
    if l:has_results
        " markers
        if !s:flake8_show_in_gutter == 0 || !s:flake8_show_in_file == 0
            call s:PlaceMarkers(l:results)
        endif
        " quickfix
        if !s:flake8_show_quickfix == 0
            " open cwindow
            execute s:flake8_quickfix_location." copen"
            setlocal wrap
            nnoremap <buffer> <silent> c :cclose<CR>
            nnoremap <buffer> <silent> q :cclose<CR>
        endif
    endif

    set nolazyredraw
    redraw!

    " Show status
    if l:has_results == 0
        echon "Flake8 check OK"
    else
        echon "Flake8 found issues"
    endif
endfunction  " }}}

"" markers

function! s:PlaceMarkers(results)  " {{{
    " in gutter?
    if !s:flake8_show_in_gutter == 0
        " define signs
        for val in values(s:markerdata)
            execute "sign define ".val['sign']." text=".val['marker']." texthl=".val['color']
        endfor
    endif

    " clear old
    call s:UnplaceMarkers()
    let s:matchids = []
    let s:signids  = []

    " place
    let l:index0 = 100
    let l:index  = l:index0
    for result in a:results
        if l:index >= (s:flake8_max_markers+l:index0)
            break
        endif
        let l:type = strpart(result.text, 0, 1)
        if has_key(s:markerdata, l:type)
            " file markers
            if !s:flake8_show_in_file == 0
                let s:matchids += [matchadd(s:markerdata[l:type]['color'],
                            \ "\\%".result.lnum."l\\%".result.col."c")]
            endif
            " gutter markers
            if !s:flake8_show_in_gutter == 0
                execute ":sign place ".index." name=".s:markerdata[l:type]['sign']
                            \ . " line=".result.lnum." file=".expand("%:p")
                let s:signids += [l:index]
            endif
            let l:index += 1
        endif
    endfor
    redraw
endfunction  " }}}

function! s:UnplaceMarkers()  " {{{
    " gutter markers
    if exists('s:signids')
        for i in s:signids
            execute ":sign unplace ".i
        endfor
        unlet s:signids
    endif
    " file markers
    if exists('s:matchids')
        for i in s:matchids
            call matchdelete(i)
        endfor
        unlet s:matchids
    endif
endfunction  " }}}

"" }}}

let &cpo = s:save_cpo
unlet s:save_cpo

