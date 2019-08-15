scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:window = gram#module#import('window')
  const s:message = gram#module#import('message')
  const s:getchar = gram#module#import('getchar')
  const s:edit = gram#module#import('edit')

  const s:map_node_base = {'rhs': {'key': 0, 'kind': ''}}
  let s:usermap = {'n': copy(s:map_node_base), 'i': copy(s:map_node_base)}

  let s:key_queue = []
endfunction

function! s:map(mode, lhs, rhs) abort
  call s:_map_impl('map', a:mode, a:lhs, a:rhs)
endfunction

function! s:noremap(mode, lhs, rhs) abort
  call s:_map_impl('noremap', a:mode, a:lhs, a:rhs)
endfunction

function! s:_map_impl(kind, mode, lhs, rhs) abort
  " Unify a:rhs here.
  if type(a:rhs) == v:t_string
    let rhs = [s:_unify_mapchar(a:rhs)]
  elseif type(a:rhs) == v:t_list
    let rhs = map(copy(a:rhs), 's:_unify_mapchar(v:val)')
  else
    call s:message.echomsg_error('gram#custom#' .. a:kind ..
          \ '(): Invalid {rhs}: ' .. string(a:rhs))
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

function! s:resolve(inputs) abort
  call s:_resolve_impl(s:key_queue + a:inputs)
endfunction

function! s:_resolve_impl(inputs) abort
  let s:key_queue = []
  let queue = copy(a:inputs)

  while !empty(queue)
    let [rhs, queue] = s:_get_rhs(s:getchar.get_mode(), queue)
    let count = 0
    while rhs.kind ==# 'map'
      let count += 1
      if count > &maxmapdepth
        call s:message.echomsg_error('recursive mapping')
        return
      endif
      let [rhs, queue] = s:_get_rhs(s:getchar.get_mode(), rhs.key + queue)
    endwhile
    call s:getchar.evaluate_keys(rhs.key)
  endwhile
endfunction

function! s:_get_rhs(mode, key_sequence) abort
  let node = s:usermap[a:mode]
  let lhs_length = 0
  let rhs = {'data': {}, 'lhs_length': 0}
  let nomap = 1

  for key in a:key_sequence
    let lhs_length += 1
    if !has_key(node, key)
      break
    endif
    let nomap = 0
    let node = node[key]
    if type(node.rhs.key) != v:t_number
      let rhs.lhs_length = lhs_length
      let rhs.data = node.rhs
    endif
  endfor
  if nomap
    return [{'key': [a:key_sequence[0]], 'kind': 'noremap'},
          \ a:key_sequence[1 :]]
  elseif len(keys(node)) >= 2
    let s:key_queue = a:key_sequence
    return [{'key': [], 'kind': 'noremap'}, []]
  elseif empty(rhs.data)
    return [{'key': a:key_sequence[: lhs_length], 'kind': 'noremap'},
          \ a:key_sequence[lhs_length :]]
  endif
  return [rhs.data, a:key_sequence[lhs_length + 1 :]]
endfunction


let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
