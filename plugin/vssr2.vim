let s:menu_items = []

function! ProcessInput(pattern)
    let l:command = '/Users/josephcocozza/Repositories/vssr/vssr --pattern ' . shellescape(a:pattern)
    echo '\nRunning command: ' . l:command
    let l:results = systemlist(l:command)
    if v:shell_error
        echohl ErrorMsg
        echom 'Error running vssr: ' . v:shell_error
        echohl None
        return
    endif
    call extend(s:menu_items, l:results)
endfunction

function! ParseInput(item)
    " should be of the form path/to/file:ln_#: line_text
    let l:parts = split(a:item, ':')

    if len(l:parts) >= 2
        let l:file = l:parts[0]
        let l:line = l:parts[1]
        call GoToFile(l:file, l:line)
    endif
endfunction

function! GoToFile(file, line)
    " Check if the file is already open in a buffer
    let l:buffer_id = bufname('%')
    if bufexists(bufnr(a:file))
        " Switch to the existing buffer
        execute 'buffer ' . bufnr(a:file)
    else
        " Open the file in a new buffer
        execute 'edit ' . a:file
    endif

    " Go to the specified line
    execute 'normal! ' . a:line . 'G'
endfunction

function! ColorText(text)
    let l:colored_text = substitute(a:text, '<match>', "", 'g')
    let l:colored_text = substitute(l:colored_text, '</match>', "", 'g')
    return l:colored_text
endfunction

function! Search()
    let s:user_search = input("vssr > ")
    call ProcessInput(s:user_search)
    let l:choices = map(copy(s:menu_items), {idx, val -> idx+1 . '. ' . val})
    let l:choice = 0
    while l:choice != -1
        redraw
        echo "Select an item (or 0 to quit):"
        for choice in l:choices
            let l:txt = ColorText(choice)
            echo txt
        endfor
        let l:choice = str2nr(input("Enter your choice: "))
        if l:choice > 0 && l:choice <= len(s:menu_items)
            call ParseInput(s:menu_items[l:choice-1])
        elseif l:choice == 0
            let l:choice = -1
        endif
    endwhile
    let s:menu_items = []
endfunction

command! Vssr call Search()
