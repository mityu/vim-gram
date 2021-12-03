scriptversion 4

let s:popupID = 0
let s:queue = []

function! gram#getchar#setup() abort
  let s:popupID = popup_create('', {
        \ 'mapping': 0,
        \ 'filter': funcref('s:filter'),
        \ 'callback': funcref('s:callback'),
        \ 'pos': 'center',
        \ 'mask': [[1, 1, 1, 1]],
        \ })
endfunction

function! gram#getchar#quit() abort
  if s:popupID != 0
    call popup_close(s:popupID)
  endif
endfunction

function! gram#getchar#get_queue() abort
  if empty(s:queue)
    return []
  endif
  return remove(s:queue, 0, -1)
endfunction

function! s:filter(winid, key) abort
  call add(s:queue, a:key)
  return 1  " No more evaluation
endfunction

function! s:callback(winid, index) abort
  " NOTE: This is temporary implementation
  " TODO: reopen
  let s:popupID = 0
endfunction
