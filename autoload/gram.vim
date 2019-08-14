scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

let s:impl = gram#module#import('impl')

function! gram#select(config, ...) abort
  return s:impl.select(a:config, get(a:000, 0, {}))
endfunction

function! gram#complete(items) abort
  call s:impl.complete(a:items)
endfunction

function! gram#complete_add(items) abort
  call s:impl.complete_add(a:items)
endfunction

function! gram#highlight_match(pattern) abort
  call s:impl.highlight_match(a:pattern)
endfunction

function! gram#set_items(items) abort
  call s:impl.set_items(a:items)
endfunction

function! gram#add_items(items) abort
  call s:impl.add_items(a:items)
endfunction

function! gram#get_items(kind) abort
  return s:impl.get_items(a:kind)
endfunction

function! gram#is_active() abort
  return s:impl.is_active()
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
