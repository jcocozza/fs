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
    let l:parts = split(a:item, ':')
    if len(l:parts) >= 2
        let l:file = l:parts[0]
        let l:line = l:parts[1]
        if filereadable(l:file)
            let l:file_content = readfile(l:file)
            return [l:file . ':' . l:line] + l:file_content
        endif
    endif
    return ['No file content available']
endfunction

function! OpenPopupWindow()
    let l:user_search = input("vssr > ")
    let l:search_results = CallVssr(l:user_search)

    " Create the popup window for the file list
    let l:list_width = float2nr(&columns * 0.4) " Adjust this for the left side width
    let l:popup_height = float2nr(&lines * 0.8)
    let l:popup_col = float2nr((&columns - l:list_width) / 2)
    let l:popup_row = float2nr((&lines - l:popup_height) / 2)

    let l:list_options = {
        \ 'line': l:popup_row,
        \ 'col': l:popup_col,
        \ 'minwidth': l:list_width,
        \ 'minheight': l:popup_height,
        \ 'maxwidth': l:list_width,
        \ 'maxheight': l:popup_height,
        \ 'title': 'VSSR Files',
        \ 'border': [],
        \ 'padding': [0,1,0,1],
        \ 'mapping': 0,
        \ 'filter': 'PopupFilter',
        \ 'callback': 'UpdateFileContent'
        \ }

    let l:list_separator = repeat('-', l:list_width - 2)
    let l:list_content = l:search_results + [l:list_separator]

    " Create the file list popup
    let s:list_winid = popup_create(l:list_content, l:list_options)
    let s:list_bufnr = winbufnr(s:list_winid)

    " Create the popup window for the file content
    let l:content_width = float2nr(&columns * 0.6) " Adjust this for the right side width
    let l:content_col = l:popup_col + l:list_width

    let l:content_options = {
        \ 'line': l:popup_row,
        \ 'col': l:content_col,
        \ 'minwidth': l:content_width,
        \ 'minheight': l:popup_height,
        \ 'maxwidth': l:content_width,
        \ 'maxheight': l:popup_height,
        \ 'title': 'File Content',
        \ 'border': [],
        \ 'padding': [0,1,0,1],
        \ 'mapping': 0
        \ }

    let l:content = ['No content available']
    " Create the file content popup
    let s:content_winid = popup_create(l:content, l:content_options)
    let s:content_bufnr = winbufnr(s:content_winid)

    " Set up syntax highlighting for matches in the list popup
    call win_execute(s:list_winid, 'syntax region vssrMatch matchgroup=vssrMatchHidden start="<match>" end="</match>" concealends')
    call win_execute(s:list_winid, 'highlight vssrMatch ctermfg=Red guifg=Red')
    call win_execute(s:list_winid, 'highlight vssrMatchHidden ctermfg=NONE guifg=NONE')
    call win_execute(s:list_winid, 'setlocal conceallevel=2')

    " Enable cursor movement in the list popup
    call popup_setoptions(s:list_winid, {'cursorline': 1})

    " Move cursor to the first line
    call win_execute(s:list_winid, 'normal! gg')

    " Store references to popups for later use
    let s:popup_winids = [s:list_winid, s:content_winid]
    let s:popup_bufnrs = [s:list_bufnr, s:content_bufnr]
endfunction

function! UpdateFileContent()
    let l:list_winid = s:popup_winids[0]
    let l:content_winid = s:popup_winids[1]
    let l:list_bufnr = s:popup_bufnrs[0]
    let l:content_bufnr = s:popup_bufnrs[1]

    let l:all_lines = getbufline(l:list_bufnr, 1, '$')
    let l:separator_line = search('^-\+$', 'n')

    if l:separator_line > 0
        let l:search_results = l:all_lines[:l:separator_line - 1]
        let l:current_line = line('.')
        if l:current_line < l:separator_line
            let l:selected_line = l:search_results[l:current_line - 1]
            let l:file_content = ParseLine(l:selected_line)
            let l:new_content = ['File content'] + l:file_content
            call popup_settext(l:content_winid, l:new_content)
            call win_execute(l:content_winid, 'normal! gg')
        endif
    endif
endfunction


function! PopupFilter(winid, key)
    let l:old_line = line('.')
    let l:max_line = len(getbufline(s:popup_bufnr, 1, '$'))
    let l:separator_line = search('^-\+$', 'n')

    if a:key == 'q' || a:key == "\<Esc>"
        call popup_close(a:winid)
        return 1
    elseif a:key == 'j' || a:key == "\<Down>"
        if l:old_line < l:max_line
            call win_execute(a:winid, 'normal! j')
            call UpdatePopupContent()
        endif
    elseif a:key == 'k' || a:key == "\<Up>"
        if l:old_line > 1
            call win_execute(a:winid, 'normal! k')
            call UpdatePopupContent()
        endif
    else
        " if a:key == \"\<CR>"
        call OpenFileUnderCursor()
        return 1
    endif

    return 1
endfunction

function! UpdatePopupContent()
    let l:all_lines = getbufline(s:popup_bufnr, 1, '$')
    let l:separator_line = search('^-\+$', 'n')

    if l:separator_line > 0
        let l:search_results = l:all_lines[:l:separator_line - 1]
        let l:current_line = line('.')
        if l:current_line < l:separator_line
            let l:selected_line = l:search_results[l:current_line - 1]
            echo "Selected line: " . l:selected_line " Debugging output
            let l:file_content = ParseLine(l:selected_line)
            echo "File content: " . join(l:file_content, "\n") " Debugging output
            let l:new_content = l:search_results + [l:all_lines[l:separator_line - 1]] + l:file_content
            call popup_settext(s:popup_winid, l:new_content)
            call win_execute(s:popup_winid, 'normal! ' . l:current_line . 'G')
        endif
    endif
endfunction

function! OpenFileUnderCursor()
    let l:line = getbufline(s:popup_bufnr, line('.'))[0]
    let l:parts = split(l:line, ':')
    if len(l:parts) >= 2
        let l:file = l:parts[0]
        let l:line_number = l:parts[1]
        " Close the popup
        call popup_close(s:popup_winid)
        " Open the file
        execute 'edit +' . l:line_number . ' ' . l:file
    endif
endfunction

function! ClosePopup(id, result)
    " This function is called when the popup is closed
    if exists('s:popup_winid')
        unlet s:popup_winid
    endif
    if exists('s:popup_bufnr')
        unlet s:popup_bufnr
    endif
endfunction

command! Op call OpenPopupWindow()
