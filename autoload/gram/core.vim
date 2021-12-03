scriptversion 4

let s:matcher_for_source = {}
let s:source_priority = []
let s:source_candidates = {}
let s:queue_candidates = {}  " Candidates that should be filtered.
let s:matched_items = {}
let s:selected_item_index = 0
let s:should_invoke_matcher = 0
" let s:should_clear_matched_items = 0

function! gram#core#setup(config) abort
  for s in a:config.sources
    " {name: "source-name", matcher: "matcher-name"}
    call add(s:source_priority, s.name)
    let s:matcher_for_source[s.name] = s.matcher
  endfor
endfunction

function! gram#core#quit() abort
  let s:matcher_for_source = {}
  let s:source_priority = []
  let s:source_candidates = {}
  let s:matched_items = {}
endfunction

function! gram#core#gather_candidates() abort
  for s in s:source_priority
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
  for s in s:source_priority
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


function! gram#core#get_active_sources() abort
  return deepcopy(s:source_priority)
endfunction

function! gram#core#select_next_item() abort
  let total = 0
  for s in s:source_priority
    let total += len(gram#core#get_matched_items(s))
  endfor
  let s:selected_item_index = (s:selected_item_index + 1) % total
endfunction

function! gram#core#select_prev_item() abort
  let total = 0
  for s in s:source_priority
    let total += len(gram#core#get_matched_items(s))
  endfor
  let s:selected_item_index = (s:selected_item_index + total - 1) % total
endfunction
