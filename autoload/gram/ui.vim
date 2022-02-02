scriptversion 4

let s:UIs = {}
let s:active_UI = {}
let s:active_UI_name = ''

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
  let s:active_UI_name = a:name
endfunction

function! gram#ui#get_active_UI() abort
  return s:active_UI_name
endfunction

function! gram#ui#quit() abort
  call s:active_UI.quit()
  let s:active_UI = {}
  let s:active_UI_name = ''
endfunction

function! gram#ui#on_selected_item_changed(idx) abort
  call s:active_UI.on_selected_item_changed(a:idx)
endfunction

function! gram#ui#on_input_changed(text, column) abort
  call s:active_UI.on_input_changed(a:text, a:column)
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
