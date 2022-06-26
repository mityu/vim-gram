scriptversion 4

let s:popupID = 0
let s:CallbackOnKeyTyped = v:null
let s:ignore_keys = ''

function! gram#getchar#setup(Callback) abort
  let s:CallbackOnKeyTyped = a:Callback
  let s:popupID = popup_create('', {
        \ 'mapping': 0,
        \ 'filter': funcref('s:filter'),
        \ 'callback': funcref('s:callback'),
        \ 'pos': 'center',
        \ 'mask': [[1, 1, 1, 1]],
        \ })
endfunction

function! gram#getchar#quit() abort
  let s:CallbackOnKeyTyped = v:null
  if s:popupID != 0
    call popup_close(s:popupID)
  endif
endfunction

function! gram#getchar#ignore_follow_keys(keys) abort
  let s:ignore_keys ..= a:keys
endfunction

function! s:filter(_, key) abort
  if s:ignore_keys[: strlen(a:key) - 1] ==# a:key
    " Go through to Vim.
    let s:ignore_keys = s:ignore_keys[strlen(a:key) :]
    return 0
  endif
  call call(s:CallbackOnKeyTyped, [a:key])
  return 1  " No more evaluation
endfunction

function! s:callback(winid, index) abort
  " NOTE: This is temporary implementation
  " TODO: reopen
  let s:popupID = 0
endfunction

function! gram#getchar#check_key_typed() abort
  return getchar(1)
endfunction
