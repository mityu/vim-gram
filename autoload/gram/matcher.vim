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
function! gram#matcher#load_from_runtimepath() abort
  let modules = globpath(&runtimepath, 'autoload/gram/matcher/*.vim', 1, 1)
        \->map({_, val -> fnamemodify(val, ':t:r')})
  for module in modules
    call call('gram#matcher#' .. module .. '#register', [])
  endfor
endfunction
