scriptversion 4

let s:input_queue = ''
let s:current_mode = ''
let s:maptree = {
      \'rhs': {},
      \'submap': {},
      \}
let s:maptree_sets = {}  " {mode: s:maptree}

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

function! gram#mapping#add_typed_key(s) abort
  let s:input_queue ..= a:s
endfunction

function! gram#mapping#lookup_mapping() abort
  let r = s:lookup_mapping(s:current_mode, s:input_queue)
  if r.completed
    let s:input_queue = r.rest
    return r.rhs
  endif
  return ''
endfunction

function! gram#mapping#switch_mode(mode) abort
  let s:current_mode = a:mode
endfunction

function! gram#mapping#get_mode() abort
  return s:current_mode
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

" mode: string
" input: string (TODO: list<string> is better?)
function! s:lookup_mapping(mode, input) abort
  " TODO: Set safety for recursive mapping; loopCountMax variable
  " TODO: Rename `rest` to `unprocessed`
  let input = s:unify_specialchar(a:input)
  let tree = s:maptree_sets[a:mode]
  let sequence = split(input, '\zs')
  let processed = ''
  while !empty(sequence)
    let c = remove(sequence, 0)
    let processed ..= c
    if has_key(tree, c)
      let tree = tree[c]
      if keys(tree) == ['rhs']
        if tree.rhs.nomore
            return {
                  \'completed': 1,
                  \'rhs': tree.rhs.mapto,
                  \'rest': join(sequence, ''),
                  \}
        else
          let sequence = split(tree.rhs.mapto, '\zs') + sequence
          let processed = ''
          let tree = s:maptree_sets[a:mode]
        endif
      endif
    else
      if has_key(tree, 'rhs')
        if tree.rhs.nomore
          return {
                \'completed': 1,
                \'rhs': tree.rhs.mapto,
                \'rest': join(sequence, ''),
                \}
        endif
        let sequence = split(tree.rhs.mapto, '\zs') + sequence
        let processed = ''
        let tree = s:maptree_sets[a:mode]
      else
        return {
              \'completed': 1,
              \'rhs': processed,
              \'rest': join(sequence, ''),
              \}
      endif
    endif
  endwhile
  return {
        \'completed': 0,
        \'rhs': '',
        \'rest': a:input,
        \}
endfunction

function! s:unify_specialchar(map) abort
  return substitute(a:map, '<.\{-}>',
        \ '\=s:escape_specialchar(submatch(0))', 'g')
endfunction

function! s:escape_specialchar(c) abort
  return eval(printf('"%s"', '\' .. a:c))
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
