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

let g:prompt = "fs > "
let g:search_prompt = g:prompt

function! ClearSearch()
   let g:search_results = []
   let g:search_loc = 0
endfunction

function! ClearSearchAndPrompt()
   let g:search_results = []
   let g:search_loc = 0
   let g:search_prompt = g:prompt
endfunction

function! CheckFs()
    if !executable('fs')
        echo "fs not found"
        return 0
    endif
    return 1
endfunction

function! OnVssrStdout(channel, msg)
    " echo 'stdout sent ' . a:msg
    if !empty(a:msg)
        call add(g:search_results, a:msg)
        call popup_settext(g:popup_winids['list'], g:search_results)
    endif
endfunction

function! HandleError(channel, msg)
    echohl ErrorMsg
    echo "Error: " . a:msg
    echohl None
endfunction

function! HandleExit(job, status)
    " if there are no results, just say that
    if len(g:search_results) == 0
        call popup_settext(g:popup_winids['list'], "no results")
        call popup_settext(g:popup_winids['content'], "No content available")
    endif
endfunction

function! StartVssrAsync(pattern)
    let l:cmd = ['fs', '--pattern=' . a:pattern, '--path=' . getcwd()]
    echo ' command: ' . join(l:cmd, ' ')
    let l:job_id = job_start(l:cmd, {
        \ 'err_cb': function('HandleError'),
        \ 'exit_cb': function('HandleExit'),
        \ 'out_cb': function('OnVssrStdout'),
        \ })
    " echo 'job status: ' . job_status(l:job_id)
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

" Currently the menu callback serves no purpose
" everything is handled by the filter function
function! Sfvc(winid, item)
    " let l:info = g:search_results[g:search_loc]
    " let l:fileline = GetFileLine(info)
    " let l:filepath = l:fileline[0]
    " call OpenFile(filepath)
endfunction

" just useful things for debugging that don't actually get called anywhere
function! Ignore()
    echo "Key pressed: " . a:key . " (ASCII: " . printf("%d", char2nr(a:key)) . ")"
endfunction

function! ChangeFileContent(winid, key)
    let l:result = 0
    " call SearchBarFilter(a:winid, a:key)
    if a:key == "\<Esc>"
        call CloseAll()
        return l:result
    endif

    if a:key == "\<CR>"
        let l:info = g:search_results[g:search_loc]
        let l:fileline = GetFileLine(info)
        let l:filepath = l:fileline[0]
        call CloseAll()
        call OpenFile(filepath)
        return
    endif

    let l:max = len(g:search_results)
    if (a:key == "\<Down>" || a:key == '<C-N>')
        let g:search_loc = (g:search_loc + 1) % l:max
        let l:result = popup_filter_menu(a:winid, a:key)
    endif
    if (a:key == "\<Up>" || a:key == '<C-P>')
        let g:search_loc = (g:search_loc - 1) % l:max
        let l:result = popup_filter_menu(a:winid, a:key)
    endif

    let l:content_winid = g:popup_winids['content']
    if len(g:search_results) > 0
        let l:info = g:search_results[g:search_loc]
        if len(info) != 0
            let l:file_line = GetFileLine(info)
            let l:filepath = file_line[0]
            let l:line_num = file_line[1]
            call CenterAroundLine(filepath, line_num)
        endif
    endif
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

function! SearchBarFilter(winid, key)
    let l:allowed_search_keys = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
                \ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
                \ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
                \ '.', '*', '?', '^', '$', '(', ')', '[', ']', '{', '}', '|', '+', '-', '=', '~', '!', '@', '#', '%', '&', "'", '"', '<', '>', ';', ':', ' ']


    if a:key == "\<BS>" && len(g:search_prompt) > len(g:prompt)
        echo g:search_prompt
        let g:search_prompt = g:search_prompt[:-2]
        call ClearSearch()
        call popup_settext(g:popup_winids['search'], g:search_prompt)
        call StartVssrAsync(g:search_prompt[4:])
    elseif index(l:allowed_search_keys, a:key) != -1
        let g:search_prompt = g:search_prompt . a:key
        call ClearSearch()
        call popup_settext(g:popup_winids['search'], g:search_prompt)
        call StartVssrAsync(g:search_prompt[4:])
    endif

endfunction

function! SearchBar()
    " Create the popup window for the search bar
    let l:list_options = {
    \ 'pos': 'topleft',
    \ 'line': g:max_search_results + 20,
    \ 'col': -1,
    \ 'maxheight': 1,
    \ 'minheight': 1,
    \ 'maxwidth': g:max_search_results_width - 10,
    \ 'minwidth': g:max_search_results_width - 10,
    \ 'border': [],
    \ 'padding': [0,1,0,1],
    \ 'cursorline': 1,
    \ 'mapping': 0,
    \ 'filter': 'SearchBarFilter',
    \ }

    " Create the file list popup
    let g:popup_winids['search'] = popup_create(g:prompt, l:list_options)
    let g:popup_bufnrs['search'] = winbufnr(g:popup_winids['search'])
endfunction

function! Open()
    " Create the popup window for the file list
    let l:list_options = {
    \ 'pos': 'topleft',
    \ 'line': 0,
    \ 'col': -1,
    \ 'maxheight': g:max_search_results,
    \ 'minheight': g:max_search_results,
    \ 'maxwidth': g:max_search_results_width - 10,
    \ 'minwidth': g:max_search_results_width - 10,
    \ 'title': 'VSSR Files (press ESC to close)',
    \ 'border': [],
    \ 'padding': [0,1,0,1],
    \ 'cursorline': 1,
    \ 'mapping': 0,
    \ 'filter': 'ChangeFileContent',
    \ 'callback': 'Sfvc',
    \ }

    " Create the file list popup
    let g:popup_winids['list'] = popup_menu(g:search_results, l:list_options)
    let g:popup_bufnrs['list'] = winbufnr(g:popup_winids['list'])

    " Set up syntax highlighting for matches in the list popup
    call win_execute(g:popup_winids['list'], 'syntax region vssrMatch matchgroup=vssrMatchHidden start="<match>" end="</match>" concealends')
    call win_execute(g:popup_winids['list'], 'highlight vssrMatch ctermfg=Red guifg=Red')
    call win_execute(g:popup_winids['list'], 'highlight vssrMatchHidden ctermfg=NONE guifg=NONE')
    call win_execute(g:popup_winids['list'], 'setlocal conceallevel=2')

    call SearchBar()
    call OpenFileViewer()

    if len(g:search_results) > 0
        let g:search_loc = 0
    endif
endfunction

function! CloseAll()
   call popup_close(g:popup_winids['content'])
   call popup_close(g:popup_winids['list'])
   call popup_close(g:popup_winids['search'])
   call ClearSearch()
endfunction

function! Lock()
    let s:saved_modifiable = &modifiable
    let s:saved_readonly = &readonly
    setlocal nomodifiable
    setlocal readonly
endfunction

function! Unlock()
    let &modifiable = s:saved_modifiable
    let &readonly = s:saved_readonly
endfunction

function! fs#Main()
    let l:exists = CheckFs()
    if l:exists == 0
        return
    endif

    try
        call Lock()
        call Open()
    finally
        call Unlock()
    endtry
endfunction

