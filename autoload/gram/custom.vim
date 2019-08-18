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

  let s:user_option = {}
  let s:source_option = {}
  const s:default_option = {
        \ 'statusline': '%n(%i/%c)',
        \ 'prompt': '>> ',
        \ 'force_refresh': 0,
        \ 'matcher': 'multi_regexp',
        \ 'enable_nmapclear': 1,
        \ }
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

function! gram#custom#option(name, value) abort
  let s:user_option[a:name] = a:value
endfunction

function! gram#custom#matcher_add(name, matcher, on_input) abort
  call s:RegisterMatcher(a:name, a:matcher, a:on_input)
endfunction

function! s:get_option(name) abort
  if has_key(s:user_option, a:name)
    return s:user_option[a:name]
  elseif has_key(s:source_option, a:name)
    return s:source_option[a:name]
  endif
  return s:default_option[a:name]
endfunction

function! s:set_source_options(options) abort
  let s:source_option = deepcopy(a:options)
endfunction

function! s:remove_source_options() abort
  let s:source_option = {}
endfunction

call s:__init__()

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
