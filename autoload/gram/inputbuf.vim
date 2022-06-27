scriptversion 4

" The cursor column is 1 indexed as same as Vim in insert mode.
let s:text = ''
let s:column = 1
let s:Core = {}  " Functions exported by core.vim

function! gram#inputbuf#setup(Funcs) abort
  let s:Core = a:Funcs
  call gram#inputbuf#clear()
endfunction

function! gram#inputbuf#quit() abort
  let s:Core = {}
endfunction

function! s:sep_at_column() abort
  return [strpart(s:text, 0, s:column - 1), s:text[s:column - 1 :]]
endfunction

function! gram#inputbuf#add_string(c) abort
  let t = s:sep_at_column()
  let s:text = t[0] .. a:c .. t[1]
  let s:column += strlen(a:c)
  call call(s:Core.onInputChanged, [])
endfunction

function! gram#inputbuf#delete_by_pattern(p) abort
  let p = substitute(
        \a:p,
        \'\v%(^|[^\\])%(\\\\)*\zs\\\%#',
        \'\\%' .. s:column .. 'c',
        \'g')
  let [_, s, e] = matchstrpos(s:text, p)
  if s == -1
    return
  endif
  let s:text = strpart(s:text, 0, s) .. s:text[e :]
  let s:column = s + 1
  call call(s:Core.onInputChanged, [])
endfunction

function! gram#inputbuf#clear() abort
  let s:text = ''
  let s:column = 1
  call call(s:Core.onInputChanged, [])
endfunction

function! gram#inputbuf#delete_character() abort
  call gram#inputbuf#delete_by_pattern('.\%#')
endfunction

function! gram#inputbuf#delete_word() abort
  call gram#inputbuf#delete_by_pattern('\w\+\s*\%#')
endfunction

function! gram#inputbuf#move_backward() abort
  let s:column -= strlen(matchstr(s:sep_at_column()[0], '.$'))
  call call(s:Core.onCursorMoved, [])
endfunction

function! gram#inputbuf#move_forward() abort
  let s:column += strlen(matchstr(s:sep_at_column()[1], '^.'))
  call call(s:Core.onCursorMoved, [])
endfunction

function gram#inputbuf#set_text(text) abort
  let s:text = a:text
  call call(s:Core.onInputChanged, [])
endfunction

function! gram#inputbuf#get_text() abort
  return s:text
endfunction

function! gram#inputbuf#set_cursor_column(column) abort
  let s:column = a:column
endfunction

function! gram#inputbuf#get_cursor_column() abort
  return s:column
endfunction
