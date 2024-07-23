let s:popup_id = 0
let s:preview_popup_id = 0
let s:menu_items = ["foo"]
let s:results = []

func! AddItem(item)
    call add(s:menu_items, a:item)
endfunc

func! MenuCallBack(id, result)
    if a:result == -1
        return
    endif
    let l:fileStr = s:menu_items[a:result]

    let l:text_popup_id = popup_dialog(l:fileStr, #{
                \ line: 25,
                \ col: 100,
                \})
endfunc

func! PreviewItem(id, key)
    let l:selected = popup_getpos(a:id).firstline - 1
    let l:fileStr = s:menu_items[l:selected]

    if s:preview_popup_id != 0
        call popup_close(s:preview_popup_id)
    endif

    if s:preview_popup_id == 0
        let s:preview_popup_id = popup_create(l:fileStr, #{
            \ line: 'cursor+1',
            \ col: 'cursor+1',
            \ moved: 'any',
            \ wrap: 0,
            \ padding: [0,1,0,1],
            \ border: [],
            \ close: 'none',
        \})
    else
        call popup_settext(s:preview_popup_id, l:fileStr)
    endif

    call win_execute(a:id, "")

    return 0
endfunc

func! ProcessInput(pattern)
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
endfunc

function! Search()
    let s:user_search = input("vssr > ")
    call ProcessInput(s:user_search)

    let s:popup_id = popup_menu(s:menu_items, #{
        \ title: "vssr",
        \ callback: 'MenuCallBack',
        \ line: 25,
        \ col: 60,
        \ highlight: 'Question',
        \ border: [],
        \ close: 'click',
        \ padding: [1,20,1,1],
        \ filter: 'PreviewItem',
        \ })

    " \ filter: 'MenuCallBack',
    " Apply syntax highlighting to the popup
    call win_execute(s:popup_id, 'syntax region vssrMatch matchgroup=vssrMatchHidden start="<match>" end="</match>" concealends')
    call win_execute(s:popup_id, 'highlight vssrMatch ctermfg=Red guifg=Red')
    call win_execute(s:popup_id, 'highlight vssrMatchHidden ctermfg=NONE guifg=NONE')
    call win_execute(s:popup_id, 'setlocal conceallevel=2')
endfunction

command! Vssr call Search()
