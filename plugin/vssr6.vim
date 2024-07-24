" Define global variables to store popup IDs and buffer numbers
let g:popup_winids = {}
let g:popup_bufnrs = {}
let g:search_results = []
let g:search_loc = 0

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

function! OpenFileViewer()
    " Create the popup window for the file content
    let l:list_width = float2nr(&columns * 0.4)
    let l:popup_height = float2nr(&lines * 0.8)
    let l:popup_col = float2nr((&columns - l:list_width) / 2)
    let l:popup_row = float2nr((&lines - l:popup_height) / 2)
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
        \ 'mapping': 0,
        \ }

    let l:content = ['No content available']
    " Create the file content popup
    let g:popup_winids['content'] = popup_create(l:content, l:content_options)
    let g:popup_bufnrs['content'] = winbufnr(g:popup_winids['content'])
endfunction

function! ParseLine(ln)
    " should be of the form path/to/file:ln_#: line_text
    let l:parts = split(a:ln, ':')
    if len(l:parts) >= 2
        let l:file = l:parts[0]
        let l:line = l:parts[1]
        let l:file_content = join(readfile(l:file), "\n")
        return l:file_content
    endif
    return ["unable to read file content"]
endfunction

function! Sfvc(winid, item)
    let l:content_winid = g:popup_winids['content']
    let l:info = g:search_results[a:item - 1]
    let l:content = ParseLine(info)
    call popup_settext(l:content_winid, l:content)
endfunction

function! ChangeFileContent(winid, key)
    if a:key == "\<CR>" || a:key == "\<Esc>"
        return 0
    endif

    let l:max = len(g:search_results)
    if (a:key == 'j' || a:key == '<Down>' || a:key == '<C-N>')
        let g:search_loc = (g:search_loc + 1) % l:max
    endif
    if (a:key == 'k' || a:key == '<Up>' || a:key == '<C-P>')
        let g:search_loc = (g:search_loc - 1) % l:max
    endif

    let l:result = popup_filter_menu(a:winid, a:key)
    let l:content_winid = g:popup_winids['content']
    let l:info = g:search_results[g:search_loc]
    let l:content = ParseLine(info)
    call popup_settext(l:content_winid, l:content)
    return l:result
endfunction

function! Open()
    let l:user_search = input("vssr > ")
    let g:search_results = CallVssr(l:user_search)

    " Create the popup window for the file list
    let l:list_width = float2nr(&columns * 0.35)
    let l:popup_height = float2nr(&lines * 0.8)
    let l:popup_col = float2nr((&columns - l:list_width) / 2)
    let l:popup_row = float2nr((&lines - l:popup_height) / 2)
    let l:list_options = {
    \ 'line': l:popup_row,
    \ 'col': popup_col,
    \ 'minwidth': l:list_width,
    \ 'minheight': l:popup_height,
    \ 'maxwidth': l:list_width,
    \ 'maxheight': l:popup_height,
    \ 'title': 'VSSR Files',
    \ 'border': [],
    \ 'padding': [0,1,0,1],
    \ 'cursorline': 1,
    \ 'callback': 'Sfvc',
    \ 'mapping': 0,
    \ 'filter': 'ChangeFileContent',
    \ }

    " Create the file list popup
    let g:popup_winids['list'] = popup_menu(g:search_results, l:list_options)
    let g:popup_bufnrs['list'] = winbufnr(g:popup_winids['list'])

    " Set up syntax highlighting for matches in the list popup
    call win_execute(g:popup_winids['list'], 'syntax region vssrMatch matchgroup=vssrMatchHidden start="<match>" end="</match>" concealends')
    call win_execute(g:popup_winids['list'], 'highlight vssrMatch ctermfg=Red guifg=Red')
    call win_execute(g:popup_winids['list'], 'highlight vssrMatchHidden ctermfg=NONE guifg=NONE')
    call win_execute(g:popup_winids['list'], 'setlocal conceallevel=2')

    call OpenFileViewer()

    if len(g:search_results) > 0
        call Sfvc(g:popup_winids['list'], 1)
        let g:search_loc = 0
    endif
endfunction

command! Op call Open()

