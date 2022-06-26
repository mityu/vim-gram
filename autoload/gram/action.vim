scriptversion 4

let s:actions = {}

function! gram#action#register(mode, action_name, action_func) abort
  " TODO: Need to check for mode?
  if !has_key(s:actions, a:mode)
    let s:actions[a:mode] = {}
  endif
  let s:actions[a:mode][a:action_name] = a:action_func
endfunction

function! gram#action#unregister(mode, action_name) abort
  if !has_key(s:actions[a:mode], a:action_name)
    call gram#ui#notify_error(expand('<stack>'))
    call gram#ui#notify_error(
          \ printf('Internal Error: Unknown action: (%s, %s)', a:mode, a:action_name))
    return
  endif
  call remove(s:actions[a:mode], a:action_name)
endfunction

function! gram#action#get_action_func(mode, action_name) abort
  if !has_key(s:actions[a:mode], a:action_name)
    call gram#ui#notify_error(expand('<stack>'))
    call gram#ui#notify_error(
          \ printf('Internal Error: Unknown action: (%s, %s)', a:mode, a:action_name))
    return 0
  endif
  return s:actions[a:mode][a:action_name]
endfunction

function! gram#action#exists(mode, action_name) abort
  return has_key(s:actions[a:mode], a:action_name)
endfunction
