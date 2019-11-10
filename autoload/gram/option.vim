scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:message = gram#module#import('message')

  let s:source_option = {}
  let s:user_option = {}
  const s:default_option = {
        \ 'statusline': '%n%<%=(%i/%c)',
        \ 'prompt': '>> ',
        \ 'force_refresh': 0,
        \ 'matcher': 'multi_regexp',
        \ 'enable_nmapclear': 1,
        \ 'enable_imapclear': 1,
        \ 'auto_preview': 0,
        \ }
endfunction

function! s:__on_close__() abort
  call s:source_option_clear()
endfunction

function! s:user_option_set(name, value) abort
  let s:user_option[a:name] = a:value
endfunction

function! s:user_option_get(name) abort
  if has_key(s:user_option)
    return s:user_option[a:name]
  endif
  return ''
endfunction

function! s:source_option_set(options) abort
  let s:source_option = deepcopy(a:options)
endfunction

function! s:source_option_add(options) abort
  let s:source_option = extend(s:source_option, a:options, 'force')
endfunction

function! s:source_option_clear() abort
  let s:source_option = {}
endfunction

function! s:source_option_get(name) abort
  if has_key(s:source_option, a:name)
    return s:source_option[a:name]
  endif
  return ''
endfunction

function! s:get_option(name) abort
  if has_key(s:source_option, a:name)
    return s:source_option[a:name]
  elseif has_key(s:user_option, a:name)
    return s:user_option[a:name]
  elseif has_key(s:default_option, a:name)
    return s:default_option[a:name]
  else
    call s:message.echomsg_error('Invalid option name: ' .. a:name)
    return ''
  endif
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
