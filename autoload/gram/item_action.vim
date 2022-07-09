scriptversion 4

let s:actions = {}

function! gram#item_action#register(kind, action_list) abort
  if !has_key(s:actions, a:kind)
    let s:actions[a:kind] = {}
  endif
  " typename(F): func(list<dict<any>>): void
  for [name, F] in items(a:action_list)
    let s:actions[a:kind][name] = F
  endfor
endfunction

function! gram#item_action#get_action_func(action_name) abort
  let [kind, name] = split(a:action_name, ':')
  if !has_key(s:actions, kind)
    call gram#ui#notify_error(printf('Unknown kind: "%s" at "%s"', kind, a:name))
    return 0
  elseif !has_key(s:actions[kind], name)
    call gram#ui#notify_error(printf('Unknown action name: "%s" at "%s"', name, a:name))
    return 0
  endif
  return s:actions[kind][name]
endfunction

function! gram#item_action#exists(name) abort
  let [kind, name] = split(a:name, ':')
  return has_key(s:actions, kind) && has_key(s:actions[kind], name)
endfunction

" function! gram#item_action#exists_notify_error(name) abort
"   let [kind, name] = split(a:name, ':')
"   if !has_key(s:actions, kind)
"     call gram#ui#notify_error(printf('Unknown kind: "%s" at "%s"', kind, a:name))
"     return 0
"   elseif !has_key(s:actions[kind], name)
"     call gram#ui#notify_error(printf('Unknown action name: "%s" at "%s"', name, a:name))
"     return 0
"   endif
"   return 1
" endfunction
