scriptversion 4

let s:actions = {}

" TODO: Make it be able to register source-specific actions.
function! gram#actions#register(mode, action_name, action_func) abort
  if !has_key(s:actions, a:mode)
    let s:actions[a:mode] = {}
  endif
  let s:actions[a:mode][a:action_name] = a:action_func
endfunction

function! gram#actions#unregister(mode, action_name) abort
  " TODO: Check for the action is surely registered.
  call remove(s:actions[a:mode], a:action_name)
endfunction

function! gram#actions#get_action_func(mode, action_name) abort
  " TODO: Check for the action is surely registered.
  return s:actions[a:mode][a:action_name]
endfunction
