" Define global variables to store popup IDs and buffer numbers
let g:popup_winids = {}
let g:popup_bufnrs = {}
let g:search_results = []
let g:search_loc = 0

" height/width params
let g:total_length = &columns
let g:total_height = &lines

let g:max_search_results = 30
let g:max_search_results_width = float2nr(g:total_length / 2)

let g:max_file_viewer_height = g:total_height - 10
let g:max_file_viewer_width = float2nr(g:total_length / 2)

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
    let l:content_options = {
        \ 'pos': 'topleft',
        \ 'line': 0,
        \ 'col': g:max_search_results_width,
        \ 'maxwidth': g:max_file_viewer_width,
        \ 'minwidth': g:max_file_viewer_width,
        \ 'minheight': g:max_file_viewer_height,
        \ 'maxheight': g:max_file_viewer_height,
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
        " let l:file_content = join(readfile(l:file), "\n")
        let l:file_content = readfile(l:file)
        return l:file_content
    endif
    return ["unable to read file content"]
endfunction

function! GetFileLine(ln)
    " should be of the form path/to/file:ln_#: line_text
    let l:parts = split(a:ln, ':')
    if len(l:parts) >= 2
        let l:file = l:parts[0]
        let l:line = l:parts[1]
        return [l:file, l:line]
    endif
endfunction

function! OpenFile(path)
    execute 'edit ' . a:path
endfunction

function! Sfvc(winid, item)
    " let l:info = g:search_results[g:search_loc]
    " let l:fileline = GetFileLine(info)
    " let l:filepath = l:fileline[0]
    " call OpenFile(filepath)
endfunction

function! ChangeFileContent(winid, key)
    echo "Key pressed: " . a:key . " (ASCII: " . printf("%d", char2nr(a:key)) . ")"
    if a:key == "\<Esc>"
        call CloseAll()
        return 0
    endif

    if a:key == "\<CR>"
        let l:info = g:search_results[g:search_loc]
        let l:fileline = GetFileLine(info)
        let l:filepath = l:fileline[0]
        call CloseAll()
        call OpenFile(filepath)
    endif

    let l:max = len(g:search_results)
    if (a:key == 'j' || a:key == "\<Down>" || a:key == '<C-N>')
        let g:search_loc = (g:search_loc + 1) % l:max
    endif
    if (a:key == 'k' || a:key == "\<Up>" || a:key == '<C-P>')
        let g:search_loc = (g:search_loc - 1) % l:max
    endif

    let l:result = popup_filter_menu(a:winid, a:key)
    let l:content_winid = g:popup_winids['content']
    let l:info = g:search_results[g:search_loc]

    let l:file_line = GetFileLine(info)
    let l:filepath = file_line[0]
    let l:line_num = file_line[1]
    call CenterAroundLine(filepath, line_num)
    " let l:content = ParseLine(info)
    " call popup_settext(l:content_winid, l:content)
    return l:result
endfunction

function! CenterAroundLine(file, line_number)
    " read file content
    let l:content = readfile(a:file)

    " lines around target line
    let l:ctx_range = float2nr(g:max_file_viewer_height / 2)
    let l:start = max([0, a:line_number - ctx_range])
    let l:end = min([len(l:content) - 1, a:line_number + ctx_range])

    let l:display_content = l:content[l:start:l:end]

    " Highlight the target line
    let l:highlighted_content = []
    for l:i in range(len(l:display_content))
        if l:i + 1 == a:line_number - l:start
            call add(l:highlighted_content, '<match>'.l:display_content[l:i].'</match>')
        else
            call add(l:highlighted_content, l:display_content[l:i])
        endif
    endfor
    let l:content_winid = g:popup_winids['content']
    call popup_settext(l:content_winid, l:highlighted_content)
    call win_execute(l:content_winid, 'syntax region vssrMatch matchgroup=vssrMatchHidden start="<match>" end="</match>" concealends')
    call win_execute(l:content_winid, 'highlight vssrMatch ctermfg=Red guifg=Red')
    call win_execute(l:content_winid, 'highlight vssrMatchHidden ctermfg=NONE guifg=NONE')
    call win_execute(l:content_winid, 'setlocal conceallevel=2')
endfunction

function! Open()
    let l:user_search = input("vssr > ")
    let g:search_results = CallVssr(l:user_search)

    " Create the popup window for the file list
    let l:list_width = float2nr(&columns * 0.35)
    let l:popup_height = float2nr(&lines * 0.8)
    let l:popup_col = 0  " float2nr((&columns - l:list_width) / 2)
    let l:popup_row = float2nr((&lines - l:popup_height) / 2)
    let l:list_options = {
    \ 'pos': 'topleft',
    \ 'line': 0,
    \ 'col': -1,
    \ 'maxheight': g:max_search_results,
    \ 'minheight': g:max_search_results,
    \ 'maxwidth': g:max_search_results_width - 10,
    \ 'minwidth': g:max_search_results_width - 10,
    \ 'title': 'VSSR Files',
    \ 'border': [],
    \ 'padding': [0,1,0,1],
    \ 'cursorline': 1,
    \ 'mapping': 0,
    \ 'filter': 'ChangeFileContent',
    \ 'callback': 'Sfvc',
    \ }

    " \ 'callback': 'Sfvc',
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
        let g:search_loc = 0
    endif
endfunction

function! CloseAll()
   call popup_close(g:popup_winids['content'])
   call popup_close(g:popup_winids['list'])
endfunction

command! Vssr call Open()

