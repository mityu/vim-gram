scriptversion 4
" core.vim can depend on any other script, but any other script, except for
" custom.vim, cannot depend on core.vim

let s:source_dicts = []
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
    call add(s:source_dicts, {
          \ 'name': s.name,
          \ 'matcher': s.matcher,
          \ 'candidates': [],
          \ 'matched_items': [],
          \ 'matched_items_count': 0,
          \ 'items_to_be_filtered': [],
          \})
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
  let s:source_dicts = []
endfunction

function! gram#core#get_source_dict(name) abort
  for s in s:source_dicts
    if s.name ==# a:name
      return s
    endif
  endfor
  echoerr 'unreachable:' a:name
  return {}
endfunction

function! gram#core#gather_candidates() abort
  for s in s:source_dicts
    call gram#core#gather_candidates_of_one_source(s)
  endfor
endfunction

function! gram#core#gather_candidates_of_one_source(sourcedict) abort
  call gram#core#clear_candidates(a:sourcedict)
  let s = gram#source#get(a:sourcedict.name)
  call s.gather_candidates({
        \ 'clear': funcref('gram#core#clear_candidates', [a:sourcedict]),
        \ 'add': funcref('gram#core#add_candidates', [a:sourcedict.name])
        \ })
endfunction

function! gram#core#clear_candidates(sourcedict) abort
  let a:sourcedict.candidates = []
  let a:sourcedict.items_to_be_filtered = []
endfunction

function! gram#core#add_candidates(name, candidates) abort
  " TODO: Normalize candidates
  let s = gram#core#get_source_dict(a:name)
  call extend(s.candidates, a:candidates)
  call extend(s.items_to_be_filtered, a:candidates)
  let s:should_invoke_matcher = 1
  call gram#core#invoke_matcher_with_filter_text(gram#inputbuf#get_text())
endfunction

function! gram#core#get_candidates(name) abort
  return deepcopy(gram#core#get_source_dict(a:name).candidates)
endfunction

function! gram#core#get_matcher_of(source_name) abort
  return gram#core#get_source_dict(a:source_name).matcher
endfunction

function! gram#core#invoke_matcher_with_filter_text(filter_text) abort
  let s:selected_item_index = 0
  for s in s:source_dicts
    call gram#core#invoke_matcher_of_one_matcher(s, a:filter_text)
  endfor
  let s:should_invoke_matcher = 0
endfunction

function! gram#core#invoke_matcher_of_one_matcher(sourcedict, filter_text) abort
  call gram#core#clear_matched_items(a:sourcedict)
  let m = gram#matcher#get(a:sourcedict.matcher)
  let c = remove(a:sourcedict, 'items_to_be_filtered')
  let a:sourcedict.items_to_be_filtered = []
  call m.match(c, a:filter_text,
        \ funcref('gram#core#add_matched_items', [a:sourcedict.name]))
endfunction

function! gram#core#add_matched_items(source_name, items) abort
  let s = gram#core#get_source_dict(a:source_name)
  call extend(s.matched_items, a:items)
  let total = 0
  for source in s:source_dicts
    let total += source.matched_items_count
    if source.name == a:source_name
      break
    endif
  endfor
  call extend(s.matched_items, a:items)
  let s.matched_items_count += len(a:items)
  call gram#ui#on_items_added(total, a:items)
endfunction

function! gram#core#get_matched_items(source_name) abort
  return gram#core#get_source_dict(a:source_name).matched_items
endfunction

function! gram#core#clear_matched_items(sourcedict) abort
  if empty(a:sourcedict.matched_items)
    return
  endif

  let ibegin = 0
  for s in s:source_dicts
    if s.name == a:sourcedict.name
      break
    endif
    let ibegin += s.matched_items_count
  endfor
  let iend = ibegin + a:sourcedict.matched_items_count - 1

  if iend < ibegin
    let iend = ibegin
  endif

  let a:sourcedict.matched_items = []
  let a:sourcedict.matched_items_count = 0

  call gram#ui#on_items_deleted(ibegin, iend)
endfunction

function! gram#core#get_selected_item() abort
  let total = 0
  for s in s:source_dicts
    let count = s.matched_items_count
    if (total + count) > s:selected_item_index
      return s.matched_items[s:selected_item_index - total]
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
  for s in s:source_dicts
    let s.items_to_be_filtered = deepcopy(s.candidates)
  endfor
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
  let ss = []
  for s in s:source_dicts
    call add(ss, s.name)
  endfor
  return ss
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
