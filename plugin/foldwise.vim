" vim-foldwise
"
" Fold-into-an-Outline
"
" By Jeet Sukumaran
" (C) Copyright 2018 Jeet Sukumaran
" Released under the same terms as Vim.
"
" Includes code derived from
"   -   https://github.com/vim-pandoc/vim-pandoc
"       (autoload/pandoc/folding.vim)
"       -   Felipe Morales (https://github.com/fmoralesc)
"       -   Alexey Radkov (https://github.com/lyokha)
"       -   Johannes Ranke (https://github.com/jranke)
"       -   Jorge Israel Peña (https://github.com/blaenk)
"
"

" Reload Guard {{{1
" ============================================================================
if exists("g:did_foldwise_plugin") && g:did_foldwise_plugin == 1
    finish
endif
let g:did_foldwise_plugin = 1
" }}} 1

" Compatibility Guard {{{1
" ============================================================================
" avoid line continuation issues (see ':help user_41.txt')
let s:save_cpo = &cpo
set cpo&vim
" }}}1

" Globals {{{1
" ============================================================================
let g:foldwise_mode = get(g:, "foldwise_mode", "stacked")
let g:foldwise_use_vim_markers = get(g:, "foldwise_use_vim_markers", 1)
let g:foldwise_auto_enable = get(g:, "foldwise_auto_enable", 1)
let g:foldwise_user_filetypes = get(g:, "foldwise_user_filetypes", {})
if !exists("g:foldwise_latex_levels")
    let g:foldwise_latex_levels = {
                \ "part": 1,
                \ "chapter": 1,
                \ "section": 1,
                \ "subsection": 2,
                \ "subsubsection": 3,
                \ "paragraph": 4,
                \ "subparagraph": 5,
                \ "frame": 2
                \}
endif
" }}}1

" Housekeeping Functions {{{1
" ============================================================================

function s:_foldwise_init()
    let g:foldwise_filetypes = {}
    let g:foldwise_native_filetypes = {
                \ "tex": "s:_foldwise_tex",
                \ "latex": "s:_foldwise_tex",
                \ "rst": "s:_foldwise_restructured_text",
                \ "rest": "s:_foldwise_restructured_text",
                \ "md": "s:_foldwise_markdown",
                \ "markdown": "s:_foldwise_markdown",
                \ "mkd": "s:_foldwise_markdown",
                \ "pandoc": "s:_foldwise_pandoc"
                \ }
    for key in keys(g:foldwise_native_filetypes)
        let g:foldwise_filetypes[key] = g:foldwise_native_filetypes[key]
    endfor
    for key in keys(g:foldwise_user_filetypes)
        let g:foldwise_filetypes[key] = g:foldwise_user_filetypes[key]
    endfor
endfunction!

function s:_foldwise_check_buffer()
    if g:foldwise_auto_enable
        for bft in keys(g:foldwise_filetypes)
            if &ft == bft
                call s:_foldwise_apply_to_buffer()
                break
            endif
        endfor
    endif
endfunction

function s:_foldwise_apply_to_buffer()
    setlocal foldmethod=expr
    augroup FoldwiseFastFolding
        autocmd!
        autocmd InsertEnter <buffer> call s:_foldwise_save_and_restore_foldmethod("insert-enter")
        autocmd InsertLeave <buffer> call s:_foldwise_save_and_restore_foldmethod("insert-leave")
    augroup end
    setlocal foldexpr=FoldwiseExpr()
    setlocal foldtext=FoldwiseText()
    let b:foldwise_headings = {}
endfunction!

function s:_foldwise_save_and_restore_foldmethod(mode)
    if a:mode == "insert-enter"
        let b:foldwise_foldmethod_on_insert_enter = &foldmethod
        setlocal foldmethod=manual
    elseif a:mode == "insert-leave"
        let fm = get(b:, "foldwise_foldmethod_on_insert_enter", "expr")
        execute "setlocal foldmethod=" . fm
    end
endfunction

" }}}1

" Folding Functions {{{1
" ============================================================================

function FoldwiseExpr()
    if count(map(range(1, winnr('$')), 'bufname(winbufnr(v:val))'), bufname("")) > 1
        return
    endif
    let level = -99
    let fn_name = get(g:foldwise_filetypes, &ft, "-1")
    if fn_name != "-1"
        " let level = s:_foldwise_tex(v:lnum)
        exec "let level = " . fn_name . "(" . v:lnum . ")"
        if level > 0
            if g:foldwise_mode == 'stacked'
                return ">1"
            else
                return ">" . level
            endif
        elseif level < 0
            if g:foldwise_mode == 'stacked'
                return "<1"
            else
                return "<" . abs(level)
            endif
        endif
    endif
    let vline = getline(v:lnum)
    " fold markers?
    if g:foldwise_use_vim_markers == 1
        let [fold_open, fold_close] = split(&foldmarker, ",")
        if vline =~ fold_open
            let level = matchstr(vline, fold_open . '\s*\zs\d')
            let title = matchstr(vline, '^\W*\zs.*\ze' . fold_open)
            if title == ""
                let title = "?MARKER?"
            end
            if level != ""
                let b:foldwise_headings[v:lnum] = [level, title]
                return ">".level
            else
                let b:foldwise_headings[v:lnum] = [foldlevel(v:lnum-1)+1, title]
                return "a1"
            endif
        endif
        if vline =~ fold_close
            let level = matchstr(vline, fold_close . '\s*\zs\d')
            if level != ""
                return "<".level
            else
                return "s1"
            endif
        endif
    endif
    return "="
endfunction!

function FoldwiseText()
    let stored_heading_calc = get(b:foldwise_headings, v:foldstart, [-1,-1])
    if stored_heading_calc[0] == -1
        let fn_name = get(g:foldwise_filetypes, &ft, "-1")
        if fn_name != "-1"
            exec "let level = " . fn_name . "(" . v:foldstart . ")"
            let stored_heading_calc = get(b:foldwise_headings, v:foldstart, [-1,-1])
        endif
    endif
    let level = stored_heading_calc[0]
    let title = stored_heading_calc[1]
    if title == "?MARKER?"
        let level = v:foldlevel
        let title = "[+" . v:foldlevel . "]"
    endif
    let leader = repeat(" ", (level * 2))
    return leader . '- ' . title . ' '
endfunction!

" }}}1

" Private Service Functions {{{1
" ============================================================================

function s:_foldwise_tex(focal_lnum)
    if a:focal_lnum == 1
        let b:foldwise_latex_in_document_body = 0
    elseif !exists("b:foldwise_latex_in_document_body")
        let b:foldwise_latex_in_document_body = 1
    endif
    let line_text = getline(a:focal_lnum)
    if line_text =~ '^\s*\\begin\s*{\s*document\s*}'
        let b:foldwise_latex_in_document_body = 1
        return 0
        " let b:foldwise_headings[a:focal_lnum] = [1, "(Document: HEAD)"]
        " return 1
    elseif line_text =~ '^\s*\\end\s*{\s*document\s*}'
        let b:foldwise_latex_in_document_body = 0
        return 0
        " let b:foldwise_headings[a:focal_lnum] = [1, "(Document: TAIL)"]
        " return 1
    elseif !b:foldwise_latex_in_document_body
        return 0
    endif
    let found = 0
    let latex_env_idx = 0
    let level = 0
    for latex_env in ["part", "chapter", "section", "subsection", "subsubsection", "paragraph", "subparagraph"]
        let latex_env_idx = latex_env_idx + 1
        let level = get(g:foldwise_latex_levels, latex_env, latex_env_idx)
        let match_expr = '^\s*\\' . latex_env . '\**\s*{\zs'
        let match_res = match(line_text, match_expr)
        if match_res >= 0
            let title = strpart(line_text, match_res, match(line_text, "}", match_res)-match_res)
            let b:foldwise_headings[a:focal_lnum] = [level, title]
            let found = 1
            break
        endif
    endfor
    if found
        return level
    else
        if line_text =~ '^\s*\\begin\s*{\s*frame\s*}'
            let offset = 0
            let title = ""
            while offset < 50
                " search block of lines
                let next_line = getline(a:focal_lnum+offset)
                if next_line =~ '^\s*\\end\s*{\s*frame\s*}'
                    break
                endif
                let title = matchstr(next_line, '^[^%]*\\frametitle\s*{\zs.*\ze}')
                if title != ""
                    break
                endif
                let offset = offset + 1
            endwhile
            if title == ""
                let title = "<frame>"
            endif
            let b:foldwise_headings[a:focal_lnum] = [1, title]
            return 1
        endif
        if line_text =~ '^\s*\\end\s*{\s*frame\s*}'
            return -1
        endif
    endif
    return 0
endfunction!

function! s:_is_rst_heading(focal_lnum, test_char)
    if getline(a:focal_lnum) =~ '^\s*'.a:test_char.'\{3,}'
        let overline_lnum = a:focal_lnum
        let title_line_lnum = a:focal_lnum + 1
        let underline_lnum = a:focal_lnum + 2
        let is_overline_line = 1
    else
        let overline_lnum = a:focal_lnum - 1
        let title_line_lnum = a:focal_lnum
        let underline_lnum = a:focal_lnum + 1
        let is_overline_line = 0
    endif
    let title = substitute(getline(title_line_lnum), '^\s*', '', '')
    let title_len = len(title)
    if title_len == 0
        return 0
    endif
    let has_underline = (len(matchstr(getline(underline_lnum), '^\s*' . a:test_char . '\+\s*$')) >= title_len) && (len(matchstr(getline(underline_lnum), '^\s*')) == len(matchstr(getline(title_line_lnum), '^\s*')))
    let has_overline = (len(matchstr(getline(overline_lnum), '^\s*' . a:test_char . '\+\s*$')) >= title_len) && (len(matchstr(getline(overline_lnum), '^\s*')) == len(matchstr(getline(title_line_lnum), '^\s*')))
    if is_overline_line && has_overline && has_underline
        let found =  2
    elseif has_overline && has_underline
        let found =  0 " because we captured it previously
    elseif has_underline
        let found =  1
    else
        let found =  0
    endif
    if found
        return title
    else
        return ""
    endif
endfunction

function! s:_foldwise_restructured_text(focal_lnum)
    " Sphinx style guide for heading levels:
    " 1. # with overline
    " 2. * with overline
    " 3. =
    " 4. -
    " 5. ^
    " 6. "
    let found = 0
    let level = 0
    for hc in ['#', '\*', '=', '-', '^', '"']
        let level = level + 1
        let result = s:_is_rst_heading(a:focal_lnum, hc)
        if result != ""
            let b:foldwise_headings[a:focal_lnum] = [level, result]
            let found = 1
            break
        endif
    endfor
    if found
        return level
    else
        return 0
    endif
endfunction

function! s:_foldwise_markdown(focal_lnum)
    let line = getline(a:focal_lnum)
    let atx_end = match(line, '^#\{1,6}\s\+\zs')
    if atx_end > 0
        let level = atx_end
        let title = matchstr(line, '\S.*$', atx_end)
        let b:foldwise_headings[a:focal_lnum] = [level, title]
        return level
    else
        return 0
    endif
endfunction

function! s:_foldwise_pandoc(focal_lnum)
    let level = s:_foldwise_markdown(a:focal_lnum)
    if level == 0
        let level = s:_foldwise_restructured_text(a:focal_lnum)
    endif
    return level
endfunction

" }}}1

" Define Commands {{{1
" ============================================================================
command! FoldwiseInit :call <SID>_foldwise_init()
command! FoldwiseActivate :call <SID>_foldwise_apply_to_buffer()
" }}}

" Start {{{1
" ============================================================================
call s:_foldwise_init()
augroup foldwise
    autocmd!
    " au BufNewFile,BufRead * call s:_foldwise_check_buffer()
    autocmd FileType * call s:_foldwise_check_buffer()
augroup END
" }}}1

" Restore State {{{1
" ============================================================================
" restore options
let &cpo = s:save_cpo
" }}}1
