scriptversion 4

let s:sources = {}
let s:aliases = {}

function! gram#source#register(name, source) abort
  let s:sources[a:name] = a:source
endfunction

function! gram#source#get(name) abort
  return deepcopy(s:sources[a:name])
endfunction

function! gram#source#clear() abort
  let s:sources = {}
endfunction

" Alias is necessary?
function! gram#source#alias(src, dest) abort
  let s:aliases[a:src] = a:dest
endfunction

function! gram#source#get_full_name(name) abort
  if has_key(s:aliases, a:name)
    return s:aliases[a:name]
  endif
  " TODO: Need to check if a:name is valid?
  return a:name
endfunction
