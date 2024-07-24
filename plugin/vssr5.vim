" Define global variables to store popup IDs and buffer numbers
let g:popup_winids = {}
let g:popup_bufnrs = {}

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

function! OpenPopupWindow()
    let l:user_search = input("vssr > ")
    let l:search_results = CallVssr(l:user_search)

    " Create the popup window for the file list
    let l:list_width = float2nr(&columns * 0.4)
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
    \ 'mapping': 1,
    \ 'filter': 'PopupFilter',
    \ 'cursorline': 1
    \ }

      "   'callback': 'UpdateFileContent',
    let l:list_separator = repeat('-', l:list_width - 2)
    let l:list_content = l:search_results + [l:list_separator]

    " Create the file list popup
    let g:popup_winids['list'] = popup_create(l:list_content, l:list_options)
    let g:popup_bufnrs['list'] = winbufnr(g:popup_winids['list'])

    " Create the popup window for the file content
    let l:content_width = float2nr(&columns * 0.6)
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
    let g:popup_winids['content'] = popup_create(l:content, l:content_options)
    let g:popup_bufnrs['content'] = winbufnr(g:popup_winids['content'])

    " Set up syntax highlighting for matches in the list popup
    call win_execute(g:popup_winids['list'], 'syntax region vssrMatch matchgroup=vssrMatchHidden start="<match>" end="</match>" concealends')
    call win_execute(g:popup_winids['list'], 'highlight vssrMatch ctermfg=Red guifg=Red')
    call win_execute(g:popup_winids['list'], 'highlight vssrMatchHidden ctermfg=NONE guifg=NONE')
    call win_execute(g:popup_winids['list'], 'setlocal conceallevel=2')

    " Ensure cursorline is enabled
    call popup_setoptions(g:popup_winids['list'], {'cursorline': 1})

    " Move cursor to the first line
    call win_execute(g:popup_winids['list'], 'normal! gg')
endfunction

function! PopupFilter(winid, key)
    echom 'PopupFilter called with key: ' . a:key
    let l:pos = popup_getpos(a:winid)
    let l:line_count = len(getbufline(g:popup_bufnrs['list'], 1, '$'))

    if a:key == 'q' || a:key == "\<Esc>"
        call popup_close(a:winid)
        return 1
    elseif a:key == 'j' || a:key == "\<Down>"
        if l:pos.firstline < l:line_count - l:pos.core_height + 1
            call popup_setoptions(a:winid, {'firstline': l:pos.firstline + 1})
            call UpdateFileContent()
        endif
    elseif a:key == 'k' || a:key == "\<Up>"
        if l:pos.firstline > 1
            call popup_setoptions(a:winid, {'firstline': l:pos.firstline - 1})
            call UpdateFileContent()
        endif
    elseif a:key == "\<CR>"
        call OpenFileUnderCursor()
        return 1
    endif
    return 1
endfunction


function! UpdateFileContent()
    let l:list_winid = g:popup_winids['list']
    let l:content_winid = g:popup_winids['content']
    let l:list_bufnr = g:popup_bufnrs['list']
    let l:content_bufnr = g:popup_bufnrs['content']

    let l:all_lines = getbufline(l:list_bufnr, 1, '$')
    let l:separator_line = index(l:all_lines, repeat('-', len(l:all_lines[0]))) + 1

    if l:separator_line > 0
        let l:search_results = l:all_lines[:l:separator_line - 1]
        let l:pos = popup_getpos(l:list_winid)
        let l:current_line = l:pos.firstline
        if l:current_line < l:separator_line
            let l:selected_line = l:search_results[l:current_line - 1]
            let l:file_content = ParseLine(l:selected_line)
            let l:new_content = ['File content'] + l:file_content
            call popup_settext(l:content_winid, l:new_content)
            call popup_setoptions(l:content_winid, {'firstline': 1})
        endif
    endif
endfunction

function! OpenFileUnderCursor()
    let l:line = getbufline(g:popup_bufnrs['list'], line('.'))[0]
    let l:parts = split(l:line, ':')
    if len(l:parts) >= 2
        let l:file = l:parts[0]
        let l:line_number = l:parts[1]
        " Close the popups
        call popup_close(g:popup_winids['list'])
        call popup_close(g:popup_winids['content'])
        " Open the file
        execute 'edit +' . l:line_number . ' ' . l:file
    endif
endfunction

command! Op call OpenPopupWindow()
