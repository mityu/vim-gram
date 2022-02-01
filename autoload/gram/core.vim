scriptversion 4

let s:matcher_for_source = {}
let s:source_prioritized = []
let s:source_candidates = {}
let s:queue_candidates = {}  " Candidates that should be filtered.
let s:matched_items = {}
let s:selected_item_index = 0
let s:should_invoke_matcher = 0
let s:current_mode = 'normal'
const s:valid_modes = ['normal', 'insert']
" let s:should_clear_matched_items = 0

function! gram#core#setup(config) abort
  for s in a:config.sources
    " {name: "source-name", matcher: "matcher-name"}
    call add(s:source_prioritized, s.name)
    let s:matcher_for_source[s.name] = s.matcher
  endfor
  call gram#ui#activate_UI(a:config.UI)  " TODO: Make it available to set default UI
  for m in s:valid_modes
    call gram#mapping#add_mode(m)
  endfor
endfunction

function! gram#core#quit() abort
  " TODO: Stop matcher, stop source
  let s:matcher_for_source = {}
  let s:source_prioritized = []
  let s:source_candidates = {}
  let s:matched_items = {}
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
  call extend(s:matched_items[a:source_name], a:items)
endfunction

function! gram#core#get_matched_items(source_name) abort
  return s:matched_items[a:source_name]
endfunction

function! gram#core#clear_matched_items(source_name) abort
  let s:matched_items[a:source_name] = []
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
    " TODO: Check action exists or not and if not exists, do fallback.
    let l:F = gram#action#get_action_func(s:current_mode, r.mapto)
    call remove(r, 'mapto')
    call call(l:F, [r])
  endwhile
endfunction

function! gram#core#switch_mode(mode) abort
  if index(s:valid_modes, a:mode) == -1
    call gram#ui#notify_error(expand('<stack>'))
    call gram#ui#notify_error('Internal Error: Not a valid mode: ' .. a:mode)
    return
  endif
  let s:current_mode = 'normal'
endfunction

function! gram#core#get_mode() abort
  return s:current_mode
endfunction

function! gram#core#get_active_sources() abort
  return deepcopy(s:source_prioritized)
endfunction

function! gram#core#select_next_item() abort
  let total = 0
  for s in s:source_prioritized
    let total += len(gram#core#get_matched_items(s))
  endfor
  let s:selected_item_index = (s:selected_item_index + 1) % total
endfunction

function! gram#core#select_prev_item() abort
  let total = 0
  for s in s:source_prioritized
    let total += len(gram#core#get_matched_items(s))
  endfor
  let s:selected_item_index = (s:selected_item_index + total - 1) % total
endfunction
