scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  if exists('s:did_init')
    return
  endif
  let s:did_init = 1
  const s:RegisterMatcher = gram#module#import('matcher').register
  const s:message = gram#module#import('message')
  const s:mapping = gram#module#import('mapping')
  const s:option = gram#module#import('option')
endfunction

function! gram#custom#noremap(mode, lhs, rhs) abort
  call s:mapping.noremap(a:mode, a:lhs, a:rhs)
endfunction

function! gram#custom#map(mode, lhs, rhs) abort
  call s:mapping.map(a:mode, a:lhs, a:rhs)
endfunction

function! gram#custom#unmap(mode, lhs) abort
  call s:mapping.unmap(a:mode, a:lhs)
endfunction

function! gram#custom#set_option(name, value) abort
  call s:option.user_option_set(a:name, a:value)
endfunction

function! gram#custom#get_option(name) abort
  return s:option.user_option_get(a:name)
endfunction

function! gram#custom#matcher_add(name, matcher, on_input) abort
  call s:RegisterMatcher(a:name, a:matcher, a:on_input)
endfunction

call s:__init__()

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
