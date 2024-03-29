scriptversion 4
" core.vim can depend on any other script, but any other script, except for
" custom.vim, cannot depend on core.vim

let s:source_dicts = []
let s:selected_item_index = 0
let s:fallback_on_nomap = {}
let s:current_mode = 'normal'
const s:valid_modes = ['normal', 'insert']
let s:should_block_matcher_call = 0  " Bigger than 0 when matcher shouldn't be triggered.
let s:processing_key_types = 0  " True if processing user's key types.
" let s:should_clear_matched_items = 0
let s:inputbuf_save = #{column: 0, text: ''}
let s:insertmode_specialchar_remaining = 0  " Counter for special chars that should be ignored.
let s:timer_request_preview = gram#timer#null()
let s:showing_preview = 0  " True when showing preview.

let s:is_initialize_event_fired = 0
augroup plugin-gram-dummy
  autocmd!
  autocmd User gram-initialize " Dummy
  autocmd User gram-start-pre  " Dummy
  autocmd User gram-start-post " Dummy
  autocmd User gram-quit-pre   " Dummy
  autocmd User gram-quit-post  " Dummy
augroup END

function! gram#core#setup(config) abort
  for m in s:valid_modes
    call gram#mapping#add_mode(m)
  endfor
  call gram#core#register_actions()

  if !s:is_initialize_event_fired
    call gram#source#load_from_runtimepath()
    call gram#matcher#load_from_runtimepath()
    call gram#item_action#load_from_runtimepath()
    call gram#ui#load_from_runtimepath()
    doautocmd User gram-initialize
    let s:is_initialize_event_fired = 1
  endif

  doautocmd User gram-start-pre

  let s:should_block_matcher_call = 0
  let s:processing_key_types = 0
  let s:insertmode_specialchar_remaining = 0
  let s:inputbuf_save = #{column: 0, text: ''}
  let s:timer_request_preview = gram#timer#null()
  let s:showing_preview = 0
  let s:fallback_on_nomap = {'insert': function('s:fallback_on_nomap_insert')}
  call gram#core#switch_mode('normal')

  let ui = ''
  if has_key(a:config, 'UI')
    let ui = a:config.UI
  else
    let ui = gram#option#get_global('UI', '')
    if ui ==# ''
      echohl Error
      echomsg '[gram] Please specify UI.'
      echohl NONE
      return
    endif
  endif
  call gram#ui#activate_UI(ui)

  " TODO: Read kind/default_action information from options_for_source
  for s in a:config.sources
    let matcher = s:get_option_from_config(s, 'matcher', '')
    if matcher ==# ''
      call gram#ui#notify_error('No matcher is specified for source: ' .. s.name)
      " TODO: return here?
    endif

    " let default_action = get(s, 'default_action', '')
    call add(s:source_dicts, {
          \ 'name': s.name,
          \ 'matcher': matcher,
          \ 'kinds': s:get_option_from_config(s, 'kind', ''),
          \ 'preview': s:get_option_from_config(s, 'preview', 'none'),
          \ 'preview_delay': s:get_option_from_config(s, 'preview_delay', 50),
          \ 'default_action': get(s, 'default_action', ''),
          \ 'candidates': [],
          \ 'matched_items': [],
          \ 'matched_items_count': 0,
          \ 'items_to_be_filtered': [],
          \ 'should_invoke_matcher': 0,
          \ 'should_clear_matched_items': 0,
          \})
  endfor
  call gram#mapping#set_mode_options('insert', {'handle_count': 0})
  " TODO: Pass UI options
  call gram#ui#setup(s:get_ui_option_from_config(get(a:config, 'UI_options', {})))
  call gram#inputbuf#setup({
        \ 'onInputChanged': funcref('s:on_input_changed'),
        \ 'onCursorMoved': funcref('s:on_cursor_moved'),
        \ })
  call gram#getchar#setup(funcref('gram#core#on_key_typed'))
  call s:set_select_item_idx(0)
  call gram#ui#hide_cursor()  " TODO: Really needed?
  call gram#core#gather_candidates()

  doautocmd User gram-start-post
endfunction

function! s:get_option_from_config(sourcedict, option, default) abort
  if has_key(a:sourcedict, a:option)
    return a:sourcedict[a:option]
  endif
  let v = gram#option#get_for_source(a:sourcedict.name, a:option, a:default)
  if v != a:default
    return v
  endif
  return gram#option#get_global(a:option, a:default)
endfunction

function! s:get_ui_option_from_config(config) abort
  let opt = #{
        \prompt_text: '',
        \enable_preview: 0,
        \}
  let globalConfig = gram#option#get_global('UI_options', {})
  for [k, v] in items(opt)
    if has_key(a:config, k)
      let opt[k] = a:config[k]
    elseif has_key(globalConfig, k)
      let opt[k] = globalConfig[k]
    endif
  endfor
  return opt
endfunction

function! gram#core#quit() abort
  doautocmd User gram-quit-pre

  call gram#getchar#quit()
  call gram#inputbuf#quit()
  call gram#ui#quit()
  for sdict in s:source_dicts
    " Stop item gathering
    let s = gram#source#get(sdict.name)
    if has_key(s, 'quit')
      call call(s.quit, [])
    endif

    " Stop item matching
    let m = gram#matcher#get(sdict.matcher)
    if has_key(m, 'quit')
      call call(m.quit, [])
    endif
  endfor
  let s:source_dicts = []

  doautocmd User gram-quit-post
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
  " TODO: Also clear matched items?
  let a:sourcedict.candidates = []
  let a:sourcedict.items_to_be_filtered = []
endfunction

function! gram#core#add_candidates(name, candidates) abort
  let candidates = map(a:candidates, 'gram#core#normalize_candidate(v:val)')
  let s = gram#core#get_source_dict(a:name)
  " TODO: deepcopy()?
  call extend(s.candidates, a:candidates)
  call extend(s.items_to_be_filtered, a:candidates)

  " If a source uses job to gather candidates and matcher uses
  " gram#core#check_key_typed() function, its out_cb can be called while
  " getchar() calls in gram#core#check_key_typed() in matcher.  And if the
  " out_cb is called while the getchar() calls, the function call depth can go
  " infinitely deep like this:
  "  matcher
  "  -> getchar() (in gram#core#check_key_typed())
  "  -> job's out_cb
  "  -> add_candidates() (this function)
  "  -> matcher
  "  -> ...
  " In order to avoid this problem, when this function is called while
  " getchar() calls, do not call matcher here.  The matcher is called later.
  let s.should_invoke_matcher = 1
  if !(gram#core#should_block_matcher_call() || s:processing_key_types)
    call gram#core#invoke_matcher_of_one_matcher(s, gram#inputbuf#get_text())
  endif
endfunction

function! gram#core#get_candidates(name) abort
  return deepcopy(gram#core#get_source_dict(a:name).candidates)
endfunction

function! gram#core#normalize_candidate(candidate) abort
  if type(a:candidate) == v:t_dict
    return a:candidate
  else
    return {'word': a:candidate}
  endif
endfunction

function! gram#core#invoke_matcher_with_filter_text(filter_text) abort
  for s in s:source_dicts
    call gram#core#invoke_matcher_of_one_matcher(s, a:filter_text)
  endfor
endfunction

function! gram#core#invoke_matcher_of_one_matcher(sourcedict, filter_text) abort
  if a:sourcedict.should_invoke_matcher && !s:processing_key_types
    let a:sourcedict.should_invoke_matcher = 0
    let m = gram#matcher#get(a:sourcedict.matcher)
    let c = remove(a:sourcedict, 'items_to_be_filtered')
    let a:sourcedict.items_to_be_filtered = []
    if a:filter_text ==# ''
      call gram#core#add_matched_items(a:sourcedict.name, c)
    else
      while !empty(c)
        " TODO: Make option to specify how many items to filter at once.
        " (Source specific option, set -1 to filter all items at once.)
        let items = remove(c, 0, min([99, len(c) - 1]))
        call m.match(items, a:filter_text,
              \ funcref('gram#core#add_matched_items', [a:sourcedict.name]))
        if gram#core#should_abort_matching()
          if !empty(c)
            " Note: The add_candidates() can be called and candidates can be
            " added while the should_abort_matching() call.
            let a:sourcedict.items_to_be_filtered =
                  \ c + a:sourcedict.items_to_be_filtered
            let a:sourcedict.should_invoke_matcher = 1
          endif
          let s:processing_key_types = 1
          break
        endif
      endwhile
    endif
  endif
endfunction

function! gram#core#check_request_preview() abort
  " This function is called when
  "  - selected item changed
  "  - the first matched items added
  if gram#core#get_total_matched_items_count() == 0
    return
  endif

  call s:timer_request_preview.stop()
  let sourcedict = gram#core#get_selected_item()[0]
  if sourcedict.preview ==# 'none' || sourcedict.preview ==# 'manual'
    if s:showing_preview
      " Clear preview if it's shown.
      call gram#ui#clear_preview()  " TODO: Is it truly comfortable behavior?
      let s:showing_preview = 0
    endif
    return
  endif
  if sourcedict.preview_delay == 0
    call gram#core#request_preview()
  else
    let s:timer_request_preview = gram#timer#start(
          \sourcedict.preview_delay,
          \{-> gram#core#request_preview()}
          \)
  endif
endfunction

function! gram#core#request_preview() abort
  call s:timer_request_preview.stop()
  if gram#core#get_total_matched_items_count() == 0
    return
  endif

  let [sourcedict, item] = gram#core#get_selected_item()
  if sourcedict.preview ==# 'none'
    return
  endif

  " TODO: Add checks for items are already there.
  let s = gram#source#get(sourcedict.name)
  if has_key(s, 'on_request_preview')
    let s:showing_preview = 1
    call s.on_request_preview(#{
          \file: function('gram#ui#preview_file'),
          \buffer: function('gram#ui#preview_buffer'),
          \text: function('gram#ui#preview_text'),
          \}, item)
  endif
endfunction

function! gram#core#add_matched_items(source_name, items) abort
  let s = gram#core#get_source_dict(a:source_name)

  " A small hack to reduce flickers.
  " Bad:  clear items -> call matcher -> show matched items
  " Good: call matcher -> clear items -> show matched items
  " TODO: Also clear matched items of other sources?
  " TODO: Clear marked item list?
  if s.should_clear_matched_items
    call gram#core#clear_matched_items(s)
    let s.should_clear_matched_items = 0
  endif

  if len(a:items) > 0
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

    if s:selected_item_index > total
      " Shift selected item index.
      " Note that check_request_preview() is called in set_select_item_idx(),
      " no need to call it here.
      call s:set_select_item_idx(s:selected_item_index + len(a:items))
    elseif total == 0
      " There were no matched items; do preview for the first item.
      call gram#core#check_request_preview()
    endif
  elseif gram#core#get_total_matched_items_count() == 0
    " Must be no items are matched (at least now).  Clear preview.
    call gram#ui#clear_preview()
  endif
  call gram#core#update_statusline()
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
  call gram#core#update_statusline()
endfunction

function! gram#core#get_selected_item() abort
  let total = 0
  for s in s:source_dicts
    let count = s.matched_items_count
    if (total + count) > s:selected_item_index
      return [s, s.matched_items[s:selected_item_index - total]]
    else
      let total += count
    endif
  endfor
  return []  " When no items matched, nothing is selected.
endfunction

function! gram#core#get_total_matched_items_count() abort
  return reduce(s:source_dicts, {acc, val -> acc + val.matched_items_count}, 0)
endfunction

function! gram#core#on_key_typed(c) abort
  if a:c == "\<C-c>"
    if s:current_mode == 'normal'
      call gram#core#quit()
    elseif s:current_mode == 'insert'
      call gram#core#cancel_insert()
    else
      call gram#ui#notify_error(
            \ '[gram.vim] Internal error: Unknown mode: ' .. s:current_mode)
    endif
    return
  endif
  call gram#mapping#add_typed_key(a:c)
  call s:process_inputs(0)
endfunction

function! s:on_mapping_timeout() abort
  call s:process_inputs(1)
endfunction

function! s:process_inputs(timeout) abort
  while 1
    let r = gram#mapping#lookup_mapping(s:current_mode, a:timeout)
    if r.resolved ==# ''
      " No mappings found
      break
    endif
    let [action, params] = split(r.resolved, '^[^%]*\zs\%(%\|$\)', 1)[0 : 1]
    if action ==# '' || !gram#action#exists(s:current_mode, action)
      " Fallbacks
      if has_key(s:fallback_on_nomap, s:current_mode)
        call call(s:fallback_on_nomap[s:current_mode], [r])
      endif
    else
      let l:F = gram#action#get_action_func(s:current_mode, action)
      call call(l:F, [{'count': r.count, 'count1': r.count1}, params])
    endif
  endwhile

  let s:processing_key_types = 0
  " Invoke matcher to filter items if needed.
  call gram#core#invoke_matcher_with_filter_text(gram#inputbuf#get_text())
endfunction

function! s:fallback_on_nomap_insert(r) abort
  " Ignore special characters
  " See also: vim/src/keymap.h
  " TODO: Check K_NUL for MSDOS.
  if strpart(a:r.resolved, 0, 1) ==# "\x80"
    let s:insertmode_specialchar_remaining = 2
    return
  elseif s:insertmode_specialchar_remaining > 0
    " TODO: Check strlen(a:r.resolved) or strlen(a:r.resolved) * a:r.count1?
    let s:insertmode_specialchar_remaining -= 1
    return
  endif
  call gram#inputbuf#add_string(repeat(a:r.resolved, a:r.count1))
endfunction

function! s:on_input_changed() abort
  let text = gram#inputbuf#get_text()
  let column = gram#inputbuf#get_cursor_column()
  call gram#ui#on_input_changed(text, column)
  for s in s:source_dicts
    let s.items_to_be_filtered = deepcopy(s.candidates)
    let s.should_invoke_matcher = 1
    let s.should_clear_matched_items = 1
  endfor
  call s:set_select_item_idx(0)
  " NOTE: Matcher is invoked in process_inputs() function later, so there's no
  " need to call matcher here.
endfunction

function! s:on_cursor_moved() abort
  let text = gram#inputbuf#get_text()
  let column = gram#inputbuf#get_cursor_column()
  call gram#ui#on_input_changed(text, column)
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

function! gram#core#switch_to_insert() abort
  let s:inputbuf_save.column = gram#inputbuf#get_cursor_column()
  let s:inputbuf_save.text = gram#inputbuf#get_text()
  call gram#core#switch_mode('insert')
  call gram#ui#show_cursor()
endfunction

function! gram#core#select_next_item(c, _) abort
  let total = 0
  for s in s:source_dicts
    let total += s.matched_items_count
  endfor
  if total == 0
    return
  endif
  let s:selected_item_index = (s:selected_item_index + a:c.count1) % total
  call s:set_select_item_idx(s:selected_item_index)
endfunction

function! gram#core#select_prev_item(c, _) abort
  let total = 0
  for s in s:source_dicts
    let total += s.matched_items_count
  endfor
  if total == 0
    return
  endif
  let s:selected_item_index = s:selected_item_index - a:c.count1
  while s:selected_item_index < 0
    let s:selected_item_index += total
  endwhile
  call s:set_select_item_idx(s:selected_item_index)
endfunction

function! s:set_select_item_idx(idx) abort
  let s:selected_item_index = a:idx
  call gram#ui#on_selected_item_changed(a:idx)
  call gram#core#update_statusline()
  call gram#core#check_request_preview()
endfunction

function! gram#core#item_action(c, param) abort
  let [sourcedict, item] = gram#core#get_selected_item()
  let items = [item]
  " TODO: Check marked items. If there're marked items, use them.
  let action_name = sourcedict.default_action
  if a:param !=# ''
    let action_name = a:param
  endif
  if gram#item_action#exists(action_name)
    let l:F = gram#item_action#get_action_func(action_name)
    call gram#core#quit()  " TODO: Make this optional process.
    call call(l:F, [items])
  endif
endfunction

function! gram#core#switch_to_normal() abort
  call gram#core#switch_mode('normal')
  call gram#ui#hide_cursor()
endfunction

function! gram#core#cancel_insert() abort
  call gram#inputbuf#set_cursor_column(s:inputbuf_save.column)
  call gram#inputbuf#set_text(s:inputbuf_save.text)
  call gram#core#switch_mode('normal')
  call gram#core#invoke_matcher_with_filter_text(s:inputbuf_save.text)
  call gram#ui#hide_cursor()
endfunction

function! gram#core#register_actions() abort
  let l:Normal = {n, F -> gram#action#register('normal', n, F)}
  call l:Normal('select-prev-item', 'gram#core#select_prev_item')
  call l:Normal('select-next-item', 'gram#core#select_next_item')
  call l:Normal('switch-to-insert', {-> gram#core#switch_to_insert()})
  call l:Normal('quit', {-> gram#core#quit()})
  call l:Normal('do-default-item-action', {c -> gram#core#item_action(c, '')})
  call l:Normal('do-item-action', 'gram#core#item_action')
  call l:Normal('request-preview', {-> gram#core#request_preview()})

  let l:Insert = {n, F -> gram#action#register('insert', n, F)}
  call l:Insert('switch-to-normal', {-> gram#core#switch_to_normal()})
  call l:Insert('cancel-insert', {-> gram#core#cancel_insert()})
  call l:Insert('delete-character', {-> gram#inputbuf#delete_character()})
  call l:Insert('delete-word', {-> gram#inputbuf#delete_word()})
  call l:Insert('move-forward', {-> gram#inputbuf#move_forward()})
  call l:Insert('move-backward', {-> gram#inputbuf#move_backward()})
  call l:Insert('clear-line', {-> gram#inputbuf#clear()})
  call l:Insert('select-prev-item', 'gram#core#select_prev_item')
  call l:Insert('select-next-item', 'gram#core#select_next_item')
  call l:Insert('request-preview', {-> gram#core#request_preview()})
endfunction

function! gram#core#feedkeys_to_vim(keys, mode = '') abort
  call gram#getchar#ignore_follow_keys(a:keys)
  call feedkeys(a:keys, a:mode)
endfunction

function! gram#core#should_abort_matching() abort
  " TODO: This function should placed in getchar.vim?
  try
    call gram#core#block_matcher_call()
    return getchar(1)
  finally
    call gram#core#unblock_matcher_call()
  endtry
endfunction

function! gram#core#block_matcher_call() abort
  let s:should_block_matcher_call += 1
endfunction

function! gram#core#unblock_matcher_call() abort
  let s:should_block_matcher_call -= 1
endfunction

function! gram#core#should_block_matcher_call() abort
  return s:should_block_matcher_call
endfunction

function! gram#core#update_statusline() abort
  " TODO: Make this configurable
  let width = gram#ui#get_statusline_width()
  let items_count = gram#core#get_total_matched_items_count()
  if items_count == 0
    let component = '(0/0)'
  else
    let component = printf('(%d/%d)', s:selected_item_index + 1, items_count)
  endif
  let component_width = strdisplaywidth(component)
  if component_width > width
    let component = matchstr(component, printf('\%%%dc', width + 1))
  else
    let component = repeat(' ', width - component_width) .. component
  endif
  call gram#ui#set_statusline(component)
endfunction
