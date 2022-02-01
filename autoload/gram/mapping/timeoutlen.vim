" A helper script to handle 'timeoutlen.'
scriptversion 4

" If user typed a key (this event should be notified via API by others such
" as gram/core.vim), (re)start a timer for timeoutlen.
let s:opt_timeoutlen = &timeoutlen
let s:timeoutlen_timer_id = 0
let s:Callback_on_timeout = v:null


" Timer related functions
function! gram#mapping#timeoutlen#start_timer() abort
  call gram#mapping#timeoutlen#stop_timer()
  let s:timeoutlen_timer_id = timer_start(s:opt_timeoutlen, funcref('s:timeoutlen_timer_callback'))
endfunction

function! gram#mapping#timeoutlen#stop_timer() abort
  if s:timeoutlen_timer_id != 0
    call timer_stop(s:timeoutlen_timer_id)
    let s:timeoutlen_timer_id = 0
  endif
endfunction

function! gram#mapping#timeoutlen#set_callback_on_timeout(F) abort
  let s:Callback_on_timeout = a:F
endfunction

function! gram#mapping#timeoutlen#set_timeoutlen(timeoutlen) abort
  let s:opt_timeoutlen = a:timeoutlen
endfunction

function! gram#mapping#timeoutlen#get_timeoutlen() abort
  return s:opt_timeoutlen
endfunction

function! s:timeoutlen_timer_callback(_) abort
  let s:timeoutlen_timer_id = 0
  let t = type(s:Callback_on_timeout)
  if t == v:t_string || t == v:t_func
    call call(s:Callback_on_timeout, [])
  endif
endfunction
