scriptversion 4

let s:sources = {}

function! gram#source#register(name, source) abort
  let s:sources[a:name] = a:source
endfunction

function! gram#source#get(name) abort
  return deepcopy(s:sources[a:name])
endfunction

function! gram#source#clear() abort
  let s:sources = {}
endfunction
