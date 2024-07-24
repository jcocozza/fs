function! CallVssr(pattern)
    let l:command = '/Users/josephcocozza/Repositories/vssr/vssr --pattern ' . shellescape(a:pattern)
    echo '\nRunning command: ' . l:command
    let l:results = systemlist(l:command)
    if v:shell_error
        echohl ErrorMsg
        echom 'Error running vssr: ' . v:shell_error
        echohl None
        return
    endif
    return l:results
endfunction

function! ParseLine(item)
    " should be of the form path/to/file:ln_#: line_text
    let l:parts = split(a:item, ':')

    if len(l:parts) >= 2
        let l:file = l:parts[0]
        let l:line = l:parts[1]
        let l:file_content = join(readfile(l:file), "\n")
        return l:file_content
    endif
endfunction

function! OpenSideBySideWindows()
    let l:user_search = input("vssr > ")
    let l:search_results = CallVssr(l:user_search)

    " Create a new vertical split
    vnew

    " Set up the left window (list)
    call setline(1, search_results)
    setlocal readonly
    setlocal nomodifiable
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal noswapfile
    setlocal nonumber norelativenumber
    file LeftWindow

    " Set up syntax highlighting for matches
    syntax region vssrMatch matchgroup=vssrMatchHidden start="<match>" end="</match>" concealends
    highlight vssrMatch ctermfg=Red guifg=Red
    highlight vssrMatchHidden ctermfg=NONE guifg=NONE
    setlocal conceallevel=2

    " Move to the right window
    wincmd l

    " Set up the right window (parsed content)
    enew
    setlocal readonly
    setlocal nomodifiable
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal noswapfile
    setlocal nonumber norelativenumber
    file RightWindow

    syntax region vssrMatch matchgroup=vssrMatchHidden start="<match>" end="</match>" concealends
    highlight vssrMatch ctermfg=Red guifg=Red
    highlight vssrMatchHidden ctermfg=NONE guifg=NONE
    setlocal conceallevel=2
    " Move back to the left window
    wincmd h

    " Set up autocommand to update right window when cursor moves in left window
    augroup SideBySideUpdate
        autocmd!
        autocmd CursorMoved LeftWindow call UpdateRightWindow()
    augroup END
endfunction

function! UpdateRightWindow()
    let current_line = getline('.')
    let parsed_content = ParseLine(current_line)

    " Switch to the right window
    wincmd l

    " Update content
    setlocal modifiable
    %delete _
    call setline(1, split(parsed_content, "\n"))
    setlocal nomodifiable

    " Switch back to the left window
    wincmd h
endfunction


command! Op call OpenSideBySideWindows()

