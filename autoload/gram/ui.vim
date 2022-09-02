scriptversion 4

let s:UIs = {}
let s:active_UI = {}
let s:active_UI_name = ''

function! gram#ui#load_from_runtimepath() abort
  let modules = globpath(&runtimepath, 'autoload/gram/ui/*.vim', 1, 1)
        \->map({_, val -> fnamemodify(val, ':t:r')})
  for module in modules
    call call('gram#ui#' .. module .. '#register', [])
  endfor
endfunction
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
    let s:active_UI_name = 'headless'
    let s:active_UI = s:headless_UI
    return
  endif
  let s:active_UI = s:UIs[a:name]
  let s:active_UI_name = a:name
endfunction

function! gram#ui#get_active_UI() abort
  return s:active_UI_name
endfunction

function! gram#ui#setup(params) abort
   call s:active_UI.setup(a:params)
endfunction

function! gram#ui#quit() abort
  call s:active_UI.quit()
  let s:active_UI = {}
  let s:active_UI_name = ''
endfunction

function! gram#ui#on_items_added(idx, items) abort
  call s:active_UI.on_items_added(a:idx, a:items)
endfunction

function! gram#ui#on_items_deleted(ibegin, iend) abort
  call s:active_UI.on_items_deleted(a:ibegin, a:iend)
endfunction

function! gram#ui#on_selected_item_changed(idx) abort
  call s:active_UI.on_selected_item_changed(a:idx)
endfunction

function! gram#ui#on_input_changed(text, column) abort
  call s:active_UI.on_input_changed(a:text, a:column)
endfunction

function! gram#ui#hide_cursor() abort
  call s:active_UI.hide_cursor()
endfunction

function! gram#ui#show_cursor() abort
  call s:active_UI.show_cursor()
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
  endfor
  echohl NONE
endfunction


let s:headless_UI = {}
function! s:headless_UI.notify_error(msg) abort
  call s:echoerr(a:msg)
endfunction

function! s:headless_UI.setup(_) abort
  " Do nothing
endfunction

function! s:headless_UI.on_input_changed(text, column) abort
  " Do nothing
endfunction

function! s:headless_UI.on_items_added(idx, items) abort
  " Do nothing
endfunction

function! s:headless_UI.on_items_deleted(ibeggin, iend) abort
  " Do nothing
endfunction

function! s:headless_UI.on_selected_item_changed(idx) abort
  " Do Nothing
endfunction

function! s:headless_UI.hide_cursor() abort
  " Do Nothing
endfunction

function! s:headless_UI.show_cursor() abort
  " Do Nothing
endfunction

function! s:headless_UI.quit() abort
  " Do nothing.
endfunction
