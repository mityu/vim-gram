scriptversion 4

let s:UIs = {}
let s:active_UI = {}

function! gram#ui#register(name, ui) abort
  let s:UIs[a:name] = a:ui
endfunction

function! gram#ui#unregister(name) abort
  if !has_key(s:UIs, a:name)
    call s:echoerr('UI module not found: ' .. a:name)
    return
  endif
  call remove(s:UIs, a:name)
endfunction

function! gram#ui#activate_UI(name) abort
  if !has_key(s:UIs, a:name)
    call s:echoerr('Unknown UI module: ' .. a:name)
    call s:echoerr('Use built-in headless UI instead temporally.')
    return
  endif
  let s:active_UI = s:UIs[a:name]
endfunction

function! gram#ui#notify_error(msg) abort
  call s:active_UI.notify_error(a:msg)
endfunction

function! s:verify_module(m) abort
  let valid = 1
  for method in []
    if !has_key(a:m, method)
      " TODO: error
      let valid = 0
    endif
  endfor
  return valid
endfunction

function! s:echoerr(msg) abort
  echohl Error
  for m in split(a:msg, "\n")
    echomsg '[gram]' m
  echohl NONE
endfunction


let s:headless_UI = {}
function! s:headless_UI.notify_error(msg) abort
  call s:echoerr(a:msg)
endfunction
