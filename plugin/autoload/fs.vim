" Define global variables to store popup IDs and buffer numbers
let s:popup_winids = {}
let s:popup_bufnrs = {}
let s:search_results = []
let s:search_loc = 0

" height/width params
let s:total_length = &columns
let s:total_height = &lines

let s:max_search_results = 30
let s:max_search_results_width = float2nr(s:total_length / 2)

let s:max_file_viewer_height = s:total_height - 10
let s:max_file_viewer_width = float2nr(s:total_length / 2)

let s:prompt = "fs > "
let s:search_prompt = s:prompt
let s:job_id = v:null

function! ClearSearch()
    let s:search_results = []
    let s:search_loc = 0
    call popup_setoptions(s:popup_winids['content'], {'title': "file content will populate here"})
endfunction

function! ClearSearchAndPrompt()
   let s:search_results = []
   let s:search_loc = 0
   let s:search_prompt = s:prompt
endfunction

function! CheckFs()
    if !executable('fs')
        echo "fs not found"
        return 0
    endif
    return 1
endfunction

function! OnFsStdout(channel, msg)
    " echo 'stdout sent ' . a:msg
    if !empty(a:msg)
        call add(s:search_results, a:msg)
        call popup_settext(s:popup_winids['list'], s:search_results)
    endif
endfunction

function! HandleError(channel, msg)
    echohl ErrorMsg
    echo "Error: " . a:msg
    echohl None
endfunction

function! HandleExit(job, status)
    " if there are no results, just say that
    if len(s:search_results) == 0
        call popup_settext(s:popup_winids['list'], "no results")
        call popup_settext(s:popup_winids['content'], "No content available")
    endif
endfunction

function! StartFsAsync(pattern)
    let l:cmd = ['fs', '--pattern=' . a:pattern, '--path=' . getcwd()]
    echo ' command: ' . join(l:cmd, ' ')
    let s:job_id = job_start(l:cmd, {
        \ 'err_cb': function('HandleError'),
        \ 'exit_cb': function('HandleExit'),
        \ 'out_cb': function('OnFsStdout'),
        \ })
    " echo 'job status: ' . job_status(l:job_id)
    return s:job_id
endfunction

function! OpenFileViewer()
    " Create the popup window for the file content
    let l:content_options = {
        \ 'pos': 'topleft',
        \ 'line': 0,
        \ 'col': s:max_search_results_width,
        \ 'maxwidth': s:max_file_viewer_width,
        \ 'minwidth': s:max_file_viewer_width,
        \ 'minheight': s:max_file_viewer_height,
        \ 'maxheight': s:max_file_viewer_height,
        \ 'title': 'File Content',
        \ 'border': [],
        \ 'padding': [0,1,0,1],
        \ 'mapping': 0,
        \ }
    let l:content = ['No content available']
    " Create the file content popup
    let s:popup_winids['content'] = popup_create(l:content, l:content_options)
    let s:popup_bufnrs['content'] = winbufnr(s:popup_winids['content'])
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

function! OpenFile(path, line)
    execute 'edit +' . a:line . ' ' . a:path
endfunction

" Currently the menu callback serves no purpose
" everything is handled by the filter function
function! Sfvc(winid, item)
    " let l:info = s:search_results[s:search_loc]
    " let l:fileline = GetFileLine(info)
    " let l:filepath = l:fileline[0]
    " call OpenFile(filepath)
endfunction

" just useful things for debugging that don't actually get called anywhere
function! Ignore()
    echo "Key pressed: " . a:key . " (ASCII: " . printf("%d", char2nr(a:key)) . ")"
endfunction

function! FilterKeys(winid, key)
    let l:result = 0
    let l:allowed_search_keys = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
                \ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
                \ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
                \ '.', '*', '?', '^', '$', '(', ')', '[', ']', '{', '}', '|', '+', '-', '=', '~', '!', '@', '#', '%', '&', "'", '"', '<', '>', ';', ':', ' ']
    if a:key == "\<Esc>"
        call CloseAll()
        return l:result
    endif
    if a:key == "\<CR>"
        let l:info = s:search_results[s:search_loc]
        let l:fileline = GetFileLine(l:info)
        let l:filepath = l:fileline[0]
        let l:line_num = l:fileline[1]
        call CloseAll()
        call OpenFile(l:filepath, l:line_num)
        return
    endif
    let l:max = len(s:search_results)
    if (a:key == "\<Down>" || a:key == '<C-N>')
        let s:search_loc = (s:search_loc + 1) % l:max
    elseif (a:key == "\<Up>" || a:key == '<C-P>')
        let s:search_loc = (s:search_loc - 1) % l:max
    elseif a:key == "\<BS>" && len(s:search_prompt) > len(s:prompt)
        echo s:search_prompt
        let s:search_prompt = s:search_prompt[:-2]
        if s:job_id != v:null && job_status(s:job_id) == "run"
            " explicitly closing the channel for the job ensures that nothing
            " new gets sent to the result set
            call ch_close(s:job_id)
            call job_stop(s:job_id)
            while job_status(s:job_id) == "dead"
                " just keep in holding until job is finished
            endwhile
        endif
        call ClearSearch()
        call popup_settext(s:popup_winids['search'], s:search_prompt)
        call popup_settext(s:popup_winids['list'], "")
        let s:job_id = StartFsAsync(s:search_prompt[len(s:prompt):])
    elseif index(l:allowed_search_keys, a:key) != -1
        let s:search_prompt = s:search_prompt . a:key
        if s:job_id != v:null && job_status(s:job_id) == "run"
            " explicitly closing the channel for the job ensures that nothing
            " new gets sent to the result set
            call ch_close(s:job_id)
            call job_stop(s:job_id)
            while job_status(s:job_id) == "dead"
                " just keep in holding until job is finished
            endwhile
        endif
        call ClearSearch()
        call popup_settext(s:popup_winids['search'], s:search_prompt)
        call popup_settext(s:popup_winids['list'], "")
        let s:job_id = StartFsAsync(s:search_prompt[len(s:prompt):])
    endif
    let l:content_winid = s:popup_winids['content']
    if len(s:search_results) > 0
        let l:info = s:search_results[s:search_loc]
        if len(info) != 0
            let l:file_line = GetFileLine(info)
            let l:filepath = file_line[0]
            let l:line_num = file_line[1]
            call CenterAroundLine(filepath, line_num)
        endif
    endif
    if a:key != "\<Space>" " popup_filter_menu will close the window if space is pressed. TODO: figure out how to properly consume keys
        let l:result = popup_filter_menu(a:winid, a:key)
    endif
    return l:result
endfunction

function! CenterAroundLine(file, line_number)
    " read file content
    let l:content = readfile(a:file)

    " lines around target line
    let l:ctx_range = float2nr(s:max_file_viewer_height / 2)
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
    let l:content_winid = s:popup_winids['content']
    call popup_setoptions(l:content_winid, {'title': a:file . " | ln: " . a:line_number})
    call popup_settext(l:content_winid, l:highlighted_content)
    call win_execute(l:content_winid, 'syntax region FsMatch matchgroup=FsMatchHidden start="<match>" end="</match>" concealends')
    call win_execute(l:content_winid, 'highlight FsMatch ctermfg=Red guifg=Red')
    call win_execute(l:content_winid, 'highlight FsMatchHidden ctermfg=NONE guifg=NONE')
    call win_execute(l:content_winid, 'setlocal conceallevel=2')
endfunction

function! SearchBar()
    " Create the popup window for the search bar
    let l:list_options = {
    \ 'pos': 'topleft',
    \ 'line': s:max_search_results + 20,
    \ 'col': -1,
    \ 'maxheight': 1,
    \ 'minheight': 1,
    \ 'maxwidth': s:max_search_results_width - 10,
    \ 'minwidth': s:max_search_results_width - 10,
    \ 'title': 'Search',
    \ 'border': [],
    \ 'padding': [0,1,0,1],
    \ 'cursorline': 1,
    \ 'mapping': 0,
    \ }

    " Create the file list popup
    let s:popup_winids['search'] = popup_create(s:prompt, l:list_options)
    let s:popup_bufnrs['search'] = winbufnr(s:popup_winids['search'])
endfunction

function! Open()
    " Create the popup window for the file list
    let l:list_options = {
    \ 'pos': 'topleft',
    \ 'line': 0,
    \ 'col': -1,
    \ 'maxheight': s:max_search_results,
    \ 'minheight': s:max_search_results,
    \ 'maxwidth': s:max_search_results_width - 10,
    \ 'minwidth': s:max_search_results_width - 10,
    \ 'title': 'Fs Files (press ESC to close)',
    \ 'border': [],
    \ 'padding': [0,1,0,1],
    \ 'cursorline': 1,
    \ 'mapping': 0,
    \ 'filter': 'FilterKeys',
    \ 'callback': 'Sfvc',
    \ }

    " Create the file list popup
    let s:popup_winids['list'] = popup_menu(s:search_results, l:list_options)
    let s:popup_bufnrs['list'] = winbufnr(s:popup_winids['list'])

    " Set up syntax highlighting for matches in the list popup
    call win_execute(s:popup_winids['list'], 'syntax region FsMatch matchgroup=FsMatchHidden start="<match>" end="</match>" concealends')
    call win_execute(s:popup_winids['list'], 'highlight FsMatch ctermfg=Red guifg=Red')
    call win_execute(s:popup_winids['list'], 'highlight FsMatchHidden ctermfg=NONE guifg=NONE')
    call win_execute(s:popup_winids['list'], 'setlocal conceallevel=2')

    call SearchBar()
    call OpenFileViewer()

    if len(s:search_results) > 0
        let s:search_loc = 0
    endif
endfunction

function! CloseAll()
    call popup_close(s:popup_winids['content'])
    call popup_close(s:popup_winids['list'])
    call popup_close(s:popup_winids['search'])
    call ClearSearchAndPrompt()
endfunction

function! Lock()
    let s:base_winid = win_getid()
    execute 'silent! buffer ' . bufname('%')
    let s:saved_modifiable = &modifiable
    let s:saved_readonly = &readonly
    silent! setlocal nomodifiable
    silent! setlocal readonly
endfunction

function! Unlock()
    let s:base_winid = win_getid()
    execute 'buffer ' . bufname('%')
    let &modifiable = s:saved_modifiable
    let &readonly = s:saved_readonly
endfunction

function! fs#Main()
    let l:exists = CheckFs()
    if l:exists == 0
        return
    endif

    " call Lock()
    call Open()
endfunction

