scriptversion 4

let s:matchers = {}

function! gram#matcher#register(name, matcher) abort
  let s:matchers[a:name] = a:matcher
endfunction

function! gram#matcher#get(name) abort
  return deepcopy(s:matchers[a:name])
endfunction

function! gram#matcher#clear() abort
  let s:matchers = {}
endfunction
