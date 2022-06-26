scriptversion 4

" A headless UI module for testing.
let s:ui = {
      \ 'log': {
      \    'notify_error': [],
      \    'setup_called': 0,
      \    'selected_item_index': 0,
      \    'quit_called': 0,
      \ }}

function! s:ui.notify_error(msg) abort
  call add(self.log.notify_error, a:msg)
endfunction

function! s:ui.get_error_log() abort
  return self.log.notify_error
endfunction

function! s:ui.clear_error_log() abort
  let self.log.notify_error = []
endfunction

function! s:ui.setup() abort
  let s:ui.log.setup_called = 1
endfunction

function! s:ui.is_setup_called() abort
  return s:ui.log.setup_called
endfunction

function! s:ui.clear_setup_called() abort
  let s:ui.log.setup_called = 0
endfunction

function! s:ui.on_selected_item_changed(idx) abort
  let s:ui.log.selected_item_index = a:idx
endfunction

function! s:ui.get_selected_item_index() abort
  return s:ui.log.selected_item_index
endfunction

function! s:ui.clear_selected_item_index(idx) abort
  let s:ui.log.selected_item_index = 0
endfunction

function! s:ui.quit() abort
  let s:ui.log.quit_called = 1
endfunction

function! s:ui.is_quit_called() abort
  return s:ui.log.quit_called
endfunction

function! s:ui.clear_quit_called() abort
  let s:ui.log.quit_called = 0
endfunction
