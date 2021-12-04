scriptversion 4
" TODO: 'timeoutlen' feature should be provided as an separate program?

let s:input_queue = ''
let s:current_mode = ''
let s:maptree = {
      \'rhs': {},
      \'submap': {},
      \}
let s:maptree_sets = {}  " {mode: s:maptree}

" If user typed a key (this event should be notified via API by others such
" as gram/core.vim), (re)start a timer for timeoutlen.
let s:opt_timeoutlen = &timeoutlen
let s:timeoutlen_timer_id = 0
let s:Callback_on_timeout = v:null

" How to hold mappings:
" In 'rhs' key value, we hold mapping's right-hand-side infomation:
"   - nomore (boolean) ... If this is TRUE, we have no need to search more.
"   - mapto  (string)  ... What is mapped to
" If tree doesn't have this component, it means nothing is mapped.
"
" {
"   'a': {
"     'b': {
"       'rhs': {
"         'nomore': 1,
"         'mapto': 'rhs-of-a'
"       }
"     }
"   }
" }
" We can figure out whether the mapping exist or not by checking
" has_key(tree, 'rhs') is TRUE or not.


function! gram#mapping#add_mode(mode) abort
  if !has_key(s:maptree_sets, a:mode)
    let s:maptree_sets[a:mode] = {}
  endif
endfunction

" rhs must be a string (action-name for :noremap or new lhs for :map)
function! gram#mapping#noremap(mode, lhs, rhs) abort
  call s:map(1, a:mode, a:lhs, a:rhs)
endfunction

function! gram#mapping#map(mode, lhs, rhs) abort
  call s:map(0, a:mode, a:lhs, a:rhs)
endfunction

function! gram#mapping#unmap(mode, lhs) abort
  call s:unmap(a:mode, a:lhs)
endfunction

function! gram#mapping#add_typed_key(s) abort
  let s:input_queue ..= a:s
endfunction

function! gram#mapping#lookup_mapping() abort
  let r = s:lookup_mapping(s:current_mode, s:input_queue, 0)
  if r.completed
    let s:input_queue = r.unprocessed
    return r.rhs
  endif
  return ''
endfunction

function! gram#mapping#switch_mode(mode) abort
  let s:current_mode = a:mode
endfunction

function! gram#mapping#start_timeoutlen_timer() abort
  call gram#mapping#stop_timeoutlen_timer()
  let s:timeoutlen_timer_id = timer_start(s:opt_timeoutlen, funcref('s:timeoutlen_timer_callback'))
endfunction

function! gram#mapping#stop_timeoutlen_timer() abort
  if s:timeoutlen_timer_id != 0
    call timer_stop(s:timeoutlen_timer_id)
    let s:timeoutlen_timer_id = 0
  endif
endfunction

function! s:timeoutlen_timer_callback(_) abort
  let s:timeoutlen_timer_id = 0
  if s:input_queue ==# ''  " Do not call callback when the queue is empty
    return
  endif

  let input = s:input_queue
  let s:input_queue = ''
  let t = type(s:Callback_on_timeout)
  if t == v:t_string || t == v:t_func
    while true
      let r = s:lookup_mapping(s:current_mode, input, 1)
      call call(s:Callback_on_timeout, [r.rhs])
      if r.unprocessed == ''
        break
      endif
      let input = r.unprocessed
    endwhile
  endif
endfunction

function! gram#mapping#set_callback_on_timeout(fn) abort
  let s:Callback_on_timeout = a:fn
endfunction

function! gram#mapping#get_mode() abort
  return s:current_mode
endfunction

function! gram#mapping#set_timeoutlen(timeoutlen) abort
  let s:opt_timeoutlen = a:timeoutlen
endfunction

function! gram#mapping#get_timeoutlen() abort
  return s:opt_timeoutlen
endfunction
function! s:map(nomore, mode, lhs, rhs) abort
  let lhs = s:unify_specialchar(a:lhs)
  let tree = s:maptree_sets[a:mode]
  for c in split(lhs, '\zs')
    if !has_key(tree, c)
      let tree[c] = {}
    endif
    let tree = tree[c]
  endfor
  let tree.rhs = {
        \'nomore': a:nomore,
        \'mapto': s:unify_specialchar(a:rhs),
        \}
endfunction

function! s:unmap(mode, lhs) abort
  let lhs = split(s:unify_specialchar(a:lhs), '\zs')
  let tree = s:maptree_sets[a:mode]
  let tree_hist = []
  for c in lhs
    if !has_key(tree, c)
      " TODO: Show error in another way (and return false?)
      echo 'No mappings found for:' a:lhs
      return
    endif

    call insert(tree_hist, {'tree': tree, 'key': c})
    let tree = tree[c]
  endfor

  if !has_key(tree, 'rhs')
      " TODO: Show error in another way (and return false?)
      echo 'No mappings found for:' a:lhs
      return
  endif

  call remove(tree, 'rhs')

  " Cleanup tree; remove empty nodes
  for h in tree_hist
    if empty(h.tree[h.key])
      call remove(h.tree, h.key)
    else
      break
    endif
  endfor
endfunction

function! s:lookup_mapping(mode, input, timeout) abort
  " TODO: Set safety for recursive mapping; loopCountMax variable
  let input = s:unify_specialchar(a:input)
  let tree = s:maptree_sets[a:mode]
  let sequence = split(input, '\zs')
  let processed = ''
  let count = 0
  while !empty(sequence)
    let c = remove(sequence, 0)
    let processed ..= c
    if has_key(tree, c)
      " Suppose only this mapping is defined:
      "   (nore)map ab mapped-ab
      " When typed keys are 'ab', program reach here. In this case, we should
      " return 'mapped-ab' if it's defined by noremap, or modify input_queue
      " then try lookup mapping again if it's defined by map.
      let tree = tree[c]
      if keys(tree) == ['rhs']
        if tree.rhs.nomore
            return {
                  \'completed': 1,
                  \'rhs': tree.rhs.mapto,
                  \'unprocessed': join(sequence, ''),
                  \'count': count,
                  \'count1': count ? count : 1,
                  \}
        else
          let sequence = split(tree.rhs.mapto, '\zs') + sequence
          let processed = ''
          let tree = s:maptree_sets[a:mode]
        endif
      endif
    else
      " Suppose only these mappings are defined:
      "   (nore)map ab mapped-ab
      "   noremap abc mapped-abc
      "   noremap abd
      "       => No mapping found
      " When typed keys are 'abd', program reach here. In this case, we should
      " return 'mapped-ab' if it's defined by noremap, or modify input_queue
      " then try lookup mapping again if it's defined by map.
      if has_key(tree, 'rhs')
        if tree.rhs.nomore
          return {
                \'completed': 1,
                \'rhs': tree.rhs.mapto,
                \'unprocessed': join(sequence, ''),
                \'count': count,
                \'count1': count ? count : 1,
                \}
        endif
        let sequence = split(tree.rhs.mapto, '\zs') + sequence
        let processed = ''
        let tree = s:maptree_sets[a:mode]
      else
        " If c is an digit, treat it as a count.
        let d = s:to_digit(c)
        if d != -1
          if processed ==# c
            let count = count * 10 + d
            continue
          endif
          let processed = processed[: -2]
          call insert(sequence, c)
        endif

        return {
              \'completed': 1,
              \'rhs': processed,
              \'unprocessed': join(sequence, ''),
              \'count': count,
              \'count1': count ? count : 1,
              \}
      endif
    endif
  endwhile

  if a:timeout && has_key(tree, 'rhs')
    return {
          \'completed': 1,
          \'rhs': processed,
          \'unprocessed': '',
          \'count': count,
          \'count1': count ? count : 1,
          \}
  endif

  return {
        \'completed': 0,
        \'rhs': '',
        \'unprocessed': a:input,
        \'count': 0,
        \'count1': 1,
        \}
endfunction

function! s:unify_specialchar(map) abort
  return substitute(a:map, '<.\{-}>',
        \ '\=s:escape_specialchar(submatch(0))', 'g')
endfunction

function! s:escape_specialchar(c) abort
  return eval(printf('"%s"', '\' .. a:c))
endfunction

function! s:to_digit(c) abort
  let d = char2nr(a:c) - 48
  if 0 <= d && d <= 9
    return d
  endif
  return -1
endfunction
function! gram#mapping#_get_input_queue() abort
  return s:input_queue
endfunction

function! gram#mapping#_clear_input_queue() abort
  let s:input_queue = ''
endfunction

function! gram#mapping#_clear_mapping(mode) abort
  call remove(s:maptree_sets, a:mode)
  call gram#mapping#add_mode(a:mode)
endfunction

function! gram#mapping#_clear_entire_mapping() abort
  let s:maptree_sets = {}
endfunction

function! gram#mapping#_get_maptree_sets() abort
  return deepcopy(s:maptree_sets)
endfunction

