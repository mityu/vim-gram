scriptversion 4

let s:options_global = {}
let s:options_source_specific = {}

function! gram#option#set_global(name, value) abort
  let s:options_global[a:name] = a:value
endfunction

function! gram#option#unset_global(name) abort
  if has_key(a:name)
    call remove(s:options_global, a:name)
  endif
endfunction

function! gram#option#clear_global() abort
  let s:options_global = {}
endfunction

function! gram#option#get_global(name, default_value = 0) abort
  if has_key(s:options_global, a:name)
    return [1, s:options_global[a:name]]
  endif
  return [0, a:default_value]
endfunction

function! gram#option#set_for_source(source_name, name, value) abort
  if !has_key(s:options_source_specific, a:source_name)
    let s:options_source_specific[a:source_name] = {}
  endif
  let s:options_source_specific[a:source_name][a:name] = a:value
endfunction

function! gram#option#unset_for_source(source_name, name) abort
  if has_key(s:options_source_specific, a:source_name) &&
        \has_key(s:options_source_specific[a:source_name], a:name)
    call remove(s:options_source_specific[a:source_name], a:name)
  endif
endfunction

function! gram#option#clear_for_source(source_name) abort
  if has_key(s:options_source_specific, a:source_name)
    call remove(s:options_source_specific, a:source_name)
  endif
endfunction

function! gram#option#get_for_source(source_name, name, default_value = 0) abort
  if !has_key(s:options_source_specific, a:source_name)
    " TODO: give error?
    return [0, a:default_value]
  elseif !has_key(s:options_source_specific[a:source_name], a:name)
    " Do not need to give error.
    return [0, a:default_value]
  endif
  return [1, s:options_source_specific[a:source_name][a:name]]
endfunction

function! gram#option#get_applied(source_name, name, default_value = 0) abort
  let r = gram#option#get_for_source(a:source_name, a:name, a:default_value)
  if r[0]
    return r
  endif
  return gram#option#get_global(a:name, a:default_value)
endfunction
