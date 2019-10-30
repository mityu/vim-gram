scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:window = gram#module#import('window')
  const s:message = gram#module#import('message')
  const s:getchar = gram#module#import('getchar')
  const s:edit = gram#module#import('edit')
  const s:insertmode = gram#module#import('insertmode')
  const s:impl = gram#module#import('impl')


  const s:default_action = {
        \ 'n': {
        \
        \ 'quit': {-> s:window.background(-1)},
        \ 'select-item': {-> s:window.background(s:window.line('.') - 1)},
        \ 'select-next-item': function('s:n_action_select_next_item'),
        \ 'select-prev-item': function('s:n_action_select_prev_item'),
        \ 'preview': s:impl.invoke_previewfunc,
        \ 'start-insert': s:getchar.start_insert,
        \
        \ },
        \
        \ 'i': {
        \
        \ 'stop-insert': s:getchar.stop_insert,
        \ 'cancel-insert': s:getchar.cancel_insert,
        \ 'move-to-right': s:insertmode.move_to_right,
        \ 'move-to-left': s:insertmode.move_to_left,
        \ 'move-to-head': s:insertmode.move_to_head,
        \ 'move-to-tail': s:insertmode.move_to_tail,
        \ 'delete-char': s:insertmode.delete_char,
        \ 'delete-word': s:insertmode.delete_word,
        \ 'delete-to-the-beginning': s:insertmode.delete_to_the_beginning,
        \
        \ },
        \ }

  const s:action_helper = {
        \ 'n': {
        \ },
        \ 'i': {
        \ 'delete-by-regexp': s:insertmode.delete_string_by_regexp,
        \ 'input-string': s:insertmode.insert_string,
        \ },
        \}


  const s:map_node_base = {'rhs': {'key': 0, 'kind': ''}}
  let s:usermap = {'n': copy(s:map_node_base), 'i': copy(s:map_node_base)}


  let s:useraction = {'n': {}, 'i': {}}
  const s:useraction_default_config = {'enable_on': 'self'}
  let s:useraction_config = {}
endfunction

function! s:map_key(mode, lhs, rhs) abort
  call s:_map_impl('map', a:mode, a:lhs, a:rhs)
endfunction

function! s:map_action(mode, lhs, action_name) abort
  call s:_map_impl('action', a:mode, a:lhs, a:action_name)
endfunction

function! s:_map_impl(kind, mode, lhs, rhs) abort
  " Unify a:rhs here.
  if type(a:rhs) == v:t_string
    let rhs = [s:_unify_mapchar(a:rhs)]
  elseif type(a:rhs) == v:t_list
    let rhs = map(copy(a:rhs), 's:_unify_mapchar(v:val)')
  else
    call s:message.echomsg_error('Invalid {rhs}: ' .. string(a:rhs))
    return
  endif

  let sequence = split(s:_unify_mapchar(a:lhs), '\zs')
  let node = s:usermap[a:mode]
  for key in sequence
    if !has_key(node, key)
      let node[key] = deepcopy(s:map_node_base)
    endif
    let node = node[key]
  endfor
  let node.rhs.key = rhs
  let node.rhs.kind = a:kind
endfunction

function! s:unmap(mode, lhs) abort
  try
    let node = s:usermap[a:mode]
    let keys = split(s:_unify_mapchar(a:lhs), '\zs')
    for key in keys[: -2]
      let node = node[key]
    endfor
    call remove(node, keys[-1])
  catch /^Vim\%((\a\+)\)\=:E716:/  " s:lhs not found in s:map
    call s:message.echomsg_error('gram#custom#unmap(): {lhs} not found: ' ..
          \ a:lhs)
  endtry
endfunction

function! s:_unify_mapchar(map) abort
  return substitute(a:map, '<.\{-}>',
        \ '\=s:_get_escaped_mapchar(submatch(0))', 'g')
endfunction

function! s:_get_escaped_mapchar(key) abort
  return eval(printf('"%s"', '\' .. a:key))
endfunction

function! s:get_usermap() abort
  return s:usermap
endfunction

" @param
" id: Works like namespace.
" mode: 'n' for normal-mode, and 'i' for insert-mode.
" action: Dictionary of action infomation. The dictionary should be one of the
" following:
"   - {'name': <name>, 'kind': 'function', 'function': <Funcref/String>}
"   - {'name': <name>, 'kind': 'helper', 'helper_name': <helper-name>,
"     'helper_args': <list of args-for-helper>}
function! s:register_action(id, mode, action) abort
  if stridx(a:id, ':') != -1
    call s:message.echoerr_msg('register_action: id cannot contain ":."')
    return
  endif
  if !has_key(s:useraction_config, a:id)
    let s:useraction_config[a:id] = deepcopy(s:useraction_default_config)
  endif
  if !has_key(s:useraction[a:mode], a:id)
    let s:useraction[a:mode][a:id] = {}
  endif
  let node = s:useraction[a:mode][a:id]

  if a:action.kind ==# 'function'
    let node[a:action.name] = a:action.function
  elseif a:action.kind ==# 'helper'
    if !has_key(s:action_helper[a:mode], a:action.helper_name)
      return
    endif
    let node[a:action.name] = function(
          \ s:action_helper[a:mode][a:action.helper_name],
          \ a:action.helper_args)
  else
    return
  endif
endfunction

function! s:unregister_action(id, mode, action_name) abort
  try
    let node = s:useraction[a:mode][a:id]
    call remove(node, a:action_name)
  catch
    call s:message.echomsg_error(v:exception)
    return v:false
  endtry
  return v:true
endfunction

function! s:config_for_action_id(id, config) abort
  let s:useraction_config[a:id] = deepcopy(a:config)
endfunction

function! s:get_action_function_from_action_name(mode, action_name) abort
  " TODO: Check if the action is available with the current source or not.
  if stridx(a:action_name, ':') == -1
    " It's a built-in action.
    if !has_key(s:default_action[a:mode], a:action_name)
      call s:message.echomsg_error('Unknown action name: ' .. a:action_name)
      return
    endif
    return s:default_action[a:mode][a:action_name]
  else
    " It's a user-defined action.
    let [id; name] = split(a:action_name, ':', 1)
    let name = join(name, ':')

    if !has_key(s:useraction[a:mode], id) ||
          \ !has_key(s:useraction[a:mode][id], name)
      call s:message.echomsg_error('Unknown action name: ' .. a:action_name)
      return
    endif

    return s:useraction[a:mode][id][name]
  endif
endfunction


" Built-in actions
function! s:n_action_select_prev_item() abort
  let line = s:window.line('.')
  if line == 1
    call s:window.set_cursor_line(s:window.line('$'))
  else
    call s:window.set_cursor_line(line - 1)
  endif
  call s:impl.on_cursor_moved()
endfunction

function! s:n_action_select_next_item() abort
  let line = s:window.line('.')
  if line == s:window.line('$')
    call s:window.set_cursor_line(1)
  else
    call s:window.set_cursor_line(line + 1)
  endif
  call s:impl.on_cursor_moved()
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
