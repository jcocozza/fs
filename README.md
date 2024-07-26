# Fs

Fs is a text file search tool. It searches for regex pattern matches in the directory and subdirectories that it is told to.
By default is will start searching in the directory it is located in.

I wanted to learn a little more about vim/vimscript so I decided to build a (very) simplified version of [the_silver_searcher](https://github.com/ggreer/the_silver_searcher).
The basic design was inspired by [fzf.vim](https://github.com/junegunn/fzf.vim)

Both of these tools are way better then Fs.

## Searching in Vim
The vim plugin should work out of the box provided the `fs` binary is in your path.

Launch it with `:Fs`.
You will be prompted to enter the search pattern. After you press `<Enter>`, results will asynchronously populate in the results window.
To leave the search window press `<esc>`.
From the search window, you can start a new search with `s`.
`<Enter>` will drop you into the file that you selected.
Can use standard vim `j/k`/`<Up>/<Down>` to navigate in the resulting file list.
