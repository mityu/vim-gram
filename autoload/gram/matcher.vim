scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:message = gram#module#import('message')

  let s:matcher_obj = {'impl': {}}
  function! s:matcher_obj.on_input(input) abort
    return call(self.impl.on_input, [a:input])
  endfunction
  function! s:matcher_obj.matcher(item) abort
    return call(self.impl.matcher, [a:item])
  endfunction
  function! s:matcher_obj.init_from_func(matcher, on_input) abort
    let self.impl.matcher = a:matcher
    let self.impl.on_input = a:on_input
    return self
  endfunction
  function! s:matcher_obj.init_from_name(matcher_name) abort
    let prefix = 'gram#source#matcher#' .. a:matcher_name .. '#'
    let matcher = prefix .. 'matcher'
    let on_input = prefix .. 'on_input'
    return self.init_from_func(matcher, on_input)
  endfunction
  lockvar s:matcher_obj

  let s:loaded_matchers = {}
  let s:current_matcher = {}
endfunction

function! s:__on_close__(idx) abort
  let s:current_matcher = {}
endfunction

function! s:register(name, matcher, on_input) abort
  let s:loaded_matchers[a:name] =
        \ deepcopy(s:matcher_obj).init_from_func(a:matcher, a:on_input)
endfunction

function! s:set(name) abort
  if s:_load(a:name)
    let s:current_matcher = s:loaded_matchers[a:name]
    return 1
  endif
  return 0
endfunction

function! s:invoke_on_input(input) abort
  return s:current_matcher.on_input(a:input)
endfunction

function! s:invoke_matcher(item) abort
  return s:current_matcher.matcher(a:item)
endfunction

function! s:_load(name) abort
  if has_key(s:loaded_matchers, a:name)
    return 1
  endif

  let path = globpath(
        \ &runtimepath,
        \ 'autoload/gram/source/matcher/' .. a:name .. '.vim',
        \ v:true, v:true
        \ )
  if empty(path)
    call s:message.echomsg_error('Matcher not found: ' .. a:name)
    return 0
  endif
  let s:loaded_matchers[a:name] =
        \ deepcopy(s:matcher_obj).init_from_name(a:name)
  return 1
endfunction


let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
