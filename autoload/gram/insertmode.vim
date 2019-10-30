scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:window = gram#module#import('window')
  const s:getchar = gram#module#import('getchar')


  const s:null_input = {'text': '', 'cursor_idx': 0}
  let s:current_input = copy(s:null_input)
  let s:previous_input = copy(s:null_input)
endfunction

function! s:__on_close__() abort
  let s:current_input = copy(s:null_input)
  let s:previous_input = copy(s:null_input)
endfunction


function! s:_show_cursor() abort
  if s:getchar.get_mode() ==# 'i'
    call s:window.show_cursor(s:current_input.cursor_idx + 1)
  endif
endfunction

function! s:get_input_text() abort
  return s:current_input.text
endfunction

function! s:get_cursor_idx() abort
  return s:current_input.cursor_idx
endfunction

function! s:start_insert() abort
  let s:previous_input = copy(s:current_input)
  call s:_show_cursor()
endfunction

function! s:stop_insert() abort
  call s:window.hide_cursor()
endfunction

function! s:cancel_insert() abort
  let s:current_input = copy(s:previous_input)
  call s:window.hide_cursor()
endfunction

" Input action helper
function! s:separate_input_at_cursor_idx() abort
  return [strpart(s:current_input.text, 0, s:current_input.cursor_idx),
        \ s:current_input.text[s:current_input.cursor_idx :]]
endfunction

function! s:insert_string(str) abort
  let [prev, post] = s:separate_input_at_cursor_idx()
  let s:current_input = {
        \ 'text': prev .. a:str .. post,
        \ 'cursor_idx': s:current_input.cursor_idx + strlen(a:str)
        \ }
endfunction

function! s:delete_string_by_regexp(regexp) abort
  let sub = '\\%' .. (s:current_input.cursor_idx + 1) .. 'c'
  let regexp = substitute(a:regexp, '\v%(\\\\)*\zs\\\%#', sub, 'g')
  let [matchstr, match_start, match_end] =
        \ matchstrpos(s:current_input.text, regexp)
  if match_start == -1
    return
  endif

  let new_input_text = strpart(s:current_input.text, 0, match_start) ..
        \ s:current_input.text[match_end :]
  let s:current_input = {
        \ 'text': new_input_text,
        \ 'cursor_idx': match_start
        \ }
endfunction


function! s:delete_char() abort
  call s:delete_string_by_regexp('.\%#')
endfunction

function! s:delete_word() abort
  call s:delete_string_by_regexp('\w\+\%#')
endfunction

function! s:delete_to_the_beginning() abort
  let s:current_input.text = s:separate_input_at_cursor_idx()[1]
  let s:current_input.cursor_idx = 0
endfunction

function! s:move_to_right() abort
  let s:current_input.cursor_idx +=
        \ strlen(matchstr(s:separate_input_at_cursor_idx()[1], '^.'))
endfunction

function! s:move_to_left() abort
  let s:current_input.cursor_idx -=
        \ strlen(matchstr(s:separate_input_at_cursor_idx()[0], '.$'))
endfunction

function! s:move_to_head() abort
  let s:current_input.cursor_idx = 0
endfunction

function! s:move_to_tail() abort
  let s:current_input.cursor_idx = strlen(s:current_input.text)
endfunction


let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
