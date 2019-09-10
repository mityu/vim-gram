scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

let s:impl = gram#module#import('impl')
let s:message = gram#module#import('message')

function! gram#select(config, ...) abort
  if gram#is_active()
    call s:message.echomsg_error(
          \ 'gram.vim is active now. Please try again after closing.')
    return 0
  endif
  return s:impl.select(a:config, get(a:000, 0, {}))
endfunction

function! gram#highlight_match(pattern) abort
  if !gram#is_active()
    return
  endif
  call s:impl.highlight_match(a:pattern)
endfunction

function! gram#set_items(items) abort
  if !gram#is_active()
    return
  endif
  call s:impl.set_items(a:items)
endfunction

function! gram#add_items(items) abort
  if !gram#is_active()
    return
  endif
  call s:impl.add_items(a:items)
endfunction

function! gram#get_items(kind) abort
  if !gram#is_active()
    return a:kind ==# '' ? {'base': [], 'matched': []} : []
  endif
  return s:impl.get_items(a:kind)
endfunction

function! gram#is_active() abort
  return s:impl.is_active()
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
