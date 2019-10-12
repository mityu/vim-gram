scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:window = gram#module#import('window')
  let s:winID = 0
endfunction

function! s:__on_close__() abort
  if s:is_available()
    call popup_close(s:winID)
  endif
endfunction

function! s:_open() abort
  let s:winID = popup_create('', {
        \ 'zindex': 101,
        \ 'cursorline': 0,
        \ 'drag': 0,
        \ 'callback': function('s:_window_callback'),
        \ 'pos': 'topleft',
        \ })
endfunction

function! s:_window_callback(winid, selected_idx) abort
  let s:winID = 0
endfunction

function! s:_adjust_position() abort
  let popup_pos = popup_getpos(s:window.get_winID())
  let cursor_line = s:window.execute_func({-> line('.')})

  call popup_setoptions(s:winID, {
        \ 'line': popup_pos.core_line + cursor_line,
        \ 'col': popup_pos.core_col + (popup_pos.core_width / 2)
        \ })
endfunction

function! s:show(contents) abort
  if s:winID == 0
    call s:_open()
  else
    if !s:is_shown()
      call popup_show(s:winID)
    endif
    silent call deletebufline(winbufnr(s:winID), 1, '$')
  endif
  call s:_adjust_position()
  call setbufline(winbufnr(s:winID), 1, a:contents)
endfunction

function! s:hide() abort
  if s:is_shown()
    call popup_hide(s:winID)
  endif
endfunction

function! s:is_shown() abort
  return s:is_available() && popup_getpos(s:winID).visible
endfunction

function! s:is_available() abort
  return s:winID != 0
endfunction


let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
