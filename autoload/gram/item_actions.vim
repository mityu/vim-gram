scriptversion 4
" TODO: Make 'kind' specification necessary?

let s:actions = {}

" TODO: Make it be able to register source-specific actions.
" action_func: func(list<dict<any>>)
function! gram#item_action#register(action_name, action_func) abort
  let s:actions[a:action_name] = a:action_func
endfunction

function! gram#item_action#unregister(action_name) abort
  if !gram#item_item_action#exists(a:action_name)
    call gram#ui#notify_error('Unknown action: ' .. a:action_name)
    return
  endif
  call remove(s:actions, a:action_name)
endfunction

function! gram#item_action#get_action_func(action_name) abort
  if !gram#item_item_action#exists(a:action_name)
    call gram#ui#notify_error('Unknown action: ' .. a:action_name)
    return
  endif
  return s:actions[a:action_name]
endfunction

function! gram#item_action#exists(action_name) abort
  return has_key(s:actions, a:action_name)
endfunction
