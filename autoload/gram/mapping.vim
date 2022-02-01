scriptversion 4

let s:input_queue = ''
let s:modeopt_default = {
      \'handle_count': 1,
      \}
let s:modeopts = {}
let s:maptree_sets = {}


" Mapping related functions
"
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
"         'mapto': 'rhs-of-ab'
"       }
"     }
"   }
" }
" We can figure out whether the mapping exist or not by checking
" has_key(tree, 'rhs') is TRUE or not.
"
" Note that we only accept string as rhs. Since 1 to 1 mapping can be realized
" easily with dictionaries, supports for setting rhs to other than string
" (i.e. funcref) should be added by client plugins.
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

function! gram#mapping#lookup_mapping(mode, timeout = 0) abort
  let r = s:lookup_mapping(a:mode, s:input_queue, a:timeout)
  if r.completed
    let s:input_queue = r.unprocessed
    return {'resolved': r.rhs, 'count': r.count, 'count1': r.count1}
  endif
  return {'resolved': '', 'count': 0, 'count1': 1}
endfunction

function! s:map(nomore, mode, lhs, rhs) abort
  " TODO: Handle <Nop>
  if a:lhs ==# ''
    " TODO: Show error
    return
  endif
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
  let remove_point = {'tree': {}, 'key': ''}
  for c in lhs
    if !has_key(tree, c)
      " TODO: Show error in another way (and return false?)
      echo 'No mappings found for:' a:lhs
      return
    endif

    let count = len(tree[c])
    if count >= 3 || (count == 2 && !has_key(tree, 'rhs'))
      let remove_point.tree = {}
      let remove_point.key = ''
    elseif empty(remove_point.tree)
      let remove_point.tree = tree
      let remove_point.key = c
    endif

    let tree = tree[c]
  endfor

  if !has_key(tree, 'rhs')
      " TODO: Show error in another way (and return false?)
      echo 'No mappings found for:' a:lhs
      return
  endif


  if empty(remove_point.tree)
    call remove(tree, 'rhs')
  else
    " Cleanup tree; remove empty nodes
    call remove(remove_point.tree, remove_point.key)
  endif
endfunction

function! s:lookup_mapping(mode, input, timeouted) abort
  let tree_root = s:maptree_sets[a:mode]
  let opt = gram#mapping#get_mode_options(a:mode)
  let sequence = split(s:unify_specialchar(a:input), '\zs')
  let count = ''

  while 1
    let tree = tree_root
    let processed = ''
    let last_found_rhs = {'rhs': {}, 'lhs': ''}

    while !empty(sequence)
      if !has_key(tree, sequence[0])
        break
      endif

      let c = remove(sequence, 0)
      let processed ..= c
      let tree = tree[c]
      if has_key(tree, 'rhs')
        let last_found_rhs.rhs = tree.rhs
        let last_found_rhs.lhs = processed
      endif
    endwhile

    let rhs = {}
    let unprocessed = ''
    if has_key(tree, 'rhs')
      if len(tree) == 1 || !empty(sequence) || a:timeouted
        " Use this tree.rhs.
        let rhs = tree.rhs
        let unprocessed = join(sequence, '')
      else
        " Wait for more keys; use nothing.
        return {
              \'completed': 0,
              \'rhs': '',
              \'unprocessed': a:input,
              \'count': 0,
              \'count1': 1,
              \}
      endif
    elseif !empty(last_found_rhs.rhs)
      let rhs = last_found_rhs.rhs
      let unprocessed =
            \processed[strlen(last_found_rhs.lhs) :] .. join(sequence, '')
    else
      let keys = processed .. join(sequence, '')
      if opt.handle_count && s:is_digit(keys[0])
        let count ..= keys[0]
        let sequence = split(keys[1 :], '\zs')
        continue
      endif
      let rhs = {'nomore': 1, 'mapto': keys[0]}
      let unprocessed = keys[1 :]
    endif

    if rhs.nomore
      if opt.handle_count
        let [mapto_count, rhs.mapto] = s:separate_count_and_map(rhs.mapto)
        let count ..= mapto_count
      endif
      let c = str2nr(count)
      return {
              \'completed': 1,
              \'rhs': rhs.mapto,
              \'unprocessed': unprocessed,
              \'count': c,
              \'count1': c ? c : 1,
              \}
    endif

    let sequence = split(rhs.mapto, '\zs') + sequence
  endwhile
endfunction
function! s:unify_specialchar(map) abort
  return substitute(a:map, '<.\{-}>',
        \ '\=s:escape_specialchar(submatch(0))', 'g')
endfunction

function! s:escape_specialchar(c) abort
  return eval(printf('"%s"', '\' .. a:c))
endfunction

function! s:is_digit(c) abort
  let d = char2nr(a:c) - 48  " char2nr('0') == 48
  return 0 <= d && d <= 9
endfunction
function! s:separate_count_and_map(s) abort
  return matchlist(a:s, '^\v(\d+)?(.*)$')[1 : 2]
endfunction


" Mode and mode option related functions
function! gram#mapping#add_mode(mode) abort
  if !has_key(s:maptree_sets, a:mode)
    let s:maptree_sets[a:mode] = {}
    let s:modeopts[a:mode] = copy(s:modeopt_default)
  endif
endfunction

function! gram#mapping#delete_mode(mode) abort
  if has_key(s:maptree_sets, a:mode)
    call remove(s:maptree_sets, a:mode)
  else
    " TODO: Notify
  endif
endfunction

function! gram#mapping#set_mode_options(mode, opt)
  let opt = s:modeopts[a:mode]
  for [k, v] in items(a:opt)
    if !has_key(opt, k)
      " TODO: Show error: Invalid option name
      continue
    endif
    let opt[k] = v
  endfor
endfunction

function! gram#mapping#get_mode_options(mode)
  return copy(s:modeopts[a:mode])
endfunction


" Internal functions
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

function! gram#mapping#_get_default_mode_options() abort
  return copy(s:modeopt_default)
endfunction
