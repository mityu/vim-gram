scriptversion 4
" core.vim can depend on any other script, but any other script, except for
" custom.vim, cannot depend on core.vim

let s:matcher_for_source = {}
let s:source_prioritized = []
let s:source_candidates = {}
let s:queue_candidates = {}  " Candidates that should be filtered.
let s:matched_items = {}
let s:matched_items_counts = {}
let s:selected_item_index = 0
let s:should_invoke_matcher = 0
let s:current_mode = 'normal'
const s:valid_modes = ['normal', 'insert']
" let s:should_clear_matched_items = 0

let s:is_initialize_event_fired = 0

function! gram#core#setup(config) abort
  if !s:is_initialize_event_fired
    " doautocmd User gram-initialize
    let s:is_initialize_event_fired = 1
  endif

  call gram#core#switch_mode('normal')
  " TODO: Make it available to set default UI
  call gram#ui#activate_UI(a:config.UI)
  for s in a:config.sources
    " {name: "source-name", matcher: "matcher-name"}
    call add(s:source_prioritized, s.name)
    let s:matcher_for_source[s.name] = s.matcher
    let s:matched_items[s.name] = []
    let s:matched_items_counts[s.name] = 0
  endfor
  for m in s:valid_modes
    call gram#mapping#add_mode(m)
  endfor
  call gram#mapping#set_mode_options('insert', {'handle_count': 0})
  call gram#inputbuf#setup(funcref('s:on_input_changed'))
  call gram#getchar#setup(funcref('gram#core#on_key_typed'))
  " TODO: Pass UI options
  call gram#ui#setup({'prompt_text': '>> '})
endfunction

function! gram#core#quit() abort
  " TODO: Stop matcher, stop source
  call gram#inputbuf#quit()
  call gram#getchar#quit()
  call gram#ui#quit()
  let s:matcher_for_source = {}
  let s:source_prioritized = []
  let s:source_candidates = {}
  let s:matched_items = {}
  let s:matched_items_counts = {}
endfunction

function! gram#core#gather_candidates() abort
  for s in s:source_prioritized
    call gram#core#gather_candidates_of_one_source(s)
  endfor
endfunction

function! gram#core#gather_candidates_of_one_source(name) abort
  call gram#core#clear_candidates(a:name)
  let s = gram#source#get(a:name)
  call s.gather_candidates({
        \ 'clear': funcref('gram#core#clear_candidates', [a:name]),
        \ 'add': funcref('gram#core#add_candidates', [a:name])
        \ })
endfunction

function! gram#core#clear_candidates(name) abort
  let s:source_candidates[a:name] = []
  let s:queue_candidates[a:name] = []
endfunction

function! gram#core#add_candidates(name, candidates) abort
  " TODO: Normalize candidates
  call extend(s:source_candidates[a:name], a:candidates)
  call extend(s:queue_candidates[a:name], a:candidates)
  let s:should_invoke_matcher = 1
endfunction

function! gram#core#get_candidates(name) abort
  return deepcopy(s:source_candidates[a:name])
endfunction

function! gram#core#get_matcher_of(source_name) abort
  return s:matcher_for_source[a:source_name]
endfunction

function! gram#core#invoke_matcher_with_filter_text(filter_text) abort
  let s:selected_item_index = 0
  for s in s:source_prioritized
    call gram#core#invoke_matcher_of_one_matcher(
          \ gram#core#get_matcher_of(s), s, a:filter_text)
  endfor
  let s:should_invoke_matcher = 0
endfunction

function! gram#core#invoke_matcher_of_one_matcher(matcher_name, source_name, filter_text) abort
  call gram#core#clear_matched_items(a:source_name)
  let m = gram#matcher#get(a:matcher_name)
  let c = remove(s:queue_candidates, a:source_name)
  let s:queue_candidates[a:source_name] = []
  call m.match(c, a:filter_text,
        \ funcref('gram#core#add_matched_items', [a:source_name]))
endfunction

function! gram#core#add_matched_items(source_name, items) abort
  let total = 0
  for s in s:source_prioritized
    let total += s:matched_items_counts[s]
    if s == a:source_name
      break
    endif
  endfor
  call extend(s:matched_items[a:source_name], a:items)
  let s:matched_items_counts[a:source_name] += len(a:items)
  call gram#ui#on_items_added(total, a:items)
endfunction

function! gram#core#get_matched_items(source_name) abort
  return s:matched_items[a:source_name]
endfunction

function! gram#core#clear_matched_items(source_name) abort
  let ibegin = 0
  for s in s:source_prioritized
    if s == a:source_name
      break
    endif
    let ibegin += s:matched_items_counts[s]
  endfor
  let iend = ibegin + s:matched_items_counts[a:source_name]
  let ibegin += 1

  let s:matched_items[a:source_name] = []
  let s:matched_items_counts[a:source_name] = 0

  call gram#ui#on_items_deleted(ibegin, iend)
endfunction

function! gram#core#get_selected_item() abort
  let total = 0
  for s in s:source_prioritized
    let count = s:matched_items_counts[s]
    if (total + count) > s:selected_item_index
      let items = gram#core#get_matched_items(s)
      return items[s:selected_item_index - total]
    else
      let total += count
    endif
  endfor
  return []  " When no items matched, nothing is selected.
endfunction

function! gram#core#on_key_typed(c) abort
  call gram#mapping#add_typed_key(a:c)
  call s:process_inputs(0)
endfunction

function! s:on_mapping_timeout() abort
  call s:process_inputs(1)
endfunction

function! s:process_inputs(timeout) abort
  while 1
    let r = gram#mapping#lookup_mapping(s:current_mode, a:timeout)
    if r.mapto ==# ''
      " No mappings found
      break
    endif
    let [action, params] = split(r.mapto, '^.\{-}\zs%', 1)
    if action ==# '' || !gram#action#exists(action)
      " TODO: Do fallback
    else
      let l:F = gram#action#get_action_func(s:current_mode, r.mapto)
      call call(l:F, [{'count': r.count, 'count1': r.count1}, params])
    endif
  endwhile
endfunction

function! s:on_input_changed() abort
  let text = gram#inputbuf#get_text()
  let column = gram#inputbuf#get_cursor_column()
  call gram#ui#on_input_changed(text, column)
  call gram#core#invoke_matcher_with_filter_text(text)
endfunction

function! gram#core#switch_mode(mode) abort
  if index(s:valid_modes, a:mode) == -1
    call gram#ui#notify_error(expand('<stack>'))
    call gram#ui#notify_error('Internal Error: Not a valid mode: ' .. a:mode)
    return
  endif
  let s:current_mode = a:mode
endfunction

function! gram#core#get_mode() abort
  return s:current_mode
endfunction

function! gram#core#get_active_sources() abort
  return deepcopy(s:source_prioritized)
endfunction

function! gram#core#select_next_item(c, _) abort
  let total = 0
  for s in s:source_prioritized
    let total += len(gram#core#get_matched_items(s))
  endfor
  if total == 0
    return
  endif
  let s:selected_item_index = (s:selected_item_index + c.count1) % total
  call s:set_select_item_idx(s:selected_item_index)
endfunction

function! gram#core#select_prev_item(c, _) abort
  let total = 0
  for s in s:source_prioritized
    let total += len(gram#core#get_matched_items(s))
  endfor
  if total == 0
    return
  endif
  let s:selected_item_index = s:selected_item_index - c.count1
  while s:selected_item_index < 0
    let s:selected_item_index += total
  endwhile
  call s:set_select_item_idx(s:selected_item_idx)
endfunction

function! s:set_select_item_idx(idx) abort
  let s:selected_item_index = a:idx
  call gram#ui#on_selected_item_chagned(a:idx)
endfunction

function! gram#core#item_action(c, params) abort
  if gram#item_action#exists(params)
    let items = [gram#core#get_selected_item()]  " TODO: Check marked items
    let l:F = gram#item_action#get_action_func(params)
    call call(l:F, [items])
  endif
endfunction

function! gram#core#register_actions() abort
  let l:Normal = {n, F -> gram#action#register('normal', n, F)}
  call l:Normal('select-prev-item', 'gram#core#select_prev_item')
  call l:Normal('select-next-item', 'gram#core#select_next_item')
  call l:Normal('switch-to-insert', {-> gram#core#switch_mode('insert')})
  call l:Normal('quit', 'gram#core#quit')
  " call l:Normal('do-default-item-action', )
  call l:Normal('do-item-action', 'gram#core#item_action')

  let l:Insert = {n, F -> gram#action#register('insert', n, F)}
  call l:Insert('switch-to-normal', {-> gram#core#switch_mode('normal')})
  call l:Insert('delete-character', {-> gram#inputbuf#delete_character()})
  call l:Insert('delete-word', {-> gram#inputbuf#delete_word()})
  call l:Insert('move-left', {-> gram#inputbuf#move_left()})
  call l:Insert('move-right', {-> gram#inputbuf#move_right()})
  call l:Insert('clear-line', {-> gram#inputbuf#clear()})
endfunction

function! gram#core#map_action(mode, lhs, action_name, params = '') abort
  call gram#mapping#noremap(a:mode, a:lhs, a:action_name .. '%' .. a:params)
endfunction

function! gram#core#noremap_keys(mode, lhs, rhs) abort
  call gram#mapping#noremap(a:mode, a:lhs, a:rhs)
endfunction

function! gram#core#map_keys(mode, lhs, rhs) abort
  call gram#mapping#map(a:mode, a:lhs, a:rhs)
endfunction

function! gram#core#feedkeys_to_vim(keys, mode = '') abort
  call gram#getchar#ignore_follow_keys(a:keys)
  call feedkeys(a:keys, a:mode)
endfunction
