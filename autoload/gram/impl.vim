scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:option = gram#module#import('option')
  const s:getchar = gram#module#import('getchar')
  const s:message = gram#module#import('message')
  const s:window = gram#module#import('window')
  const s:matcher = gram#module#import('matcher')

  const s:item_skeleton =
        \ {'word': '', 'abbr': '', 'menu': '', 'user_data': ''}

  let s:default_option = {}
  let s:context = {}
  let s:source_config = {}
  let s:matcher_handler = {'timer_id': 0, 'items_queue': []}
  let s:selected_item = {}
endfunction

function! s:__on_close__() abort
  let s:context = {}
endfunction

function! s:set_selected_item(selected_idx) abort
  if a:selected_idx >= 0
    let s:selected_item = s:context.items.matched[a:selected_idx]
  else
    let s:selected_item = {}
  endif
endfunction

function! s:_init() abort
  augroup __gram_init_dummy__
    autocmd!
    autocmd User gram-first-start silent
  augroup END

  doautocmd User gram-first-start

  augroup __gram_init_dummy__
    autocmd!
  augroup END

  highlight link _gramCursor_ Cursor
  call s:_set_window_color()
  augroup __gram_colorscheme__
    autocmd!
    autocmd ColorScheme * call s:_set_window_color()
  augroup END

  let s:did_init = 1
endfunction

function! s:select(config, options) abort
  " Initialization only on the first start.
  if !exists('s:did_init')
    call s:_init()
  endif

  if !has_key(a:config, 'callback')
    call s:message.echomsg_error(
          \'Not enough config entries: Missing "callback"')
    return 0
  endif

  if !(has_key(a:config, 'completefunc') || has_key(a:config, 'items'))
    call s:message.echomsg_error(
          \'Not enough config entries: Missing "completefunc"')
    return 0
  endif
  " let requirements = []
  " let entries = keys(a:config)
  " let missing_entries = filter(requirements, 'index(entries, v:val) == -1')
  " if !empty(missing_entries)
  "   call s:message.echomsg_error(
  "        \ 'Not enough config entries: Missing ' .. string(missing_entries))
  "   return {}
  " endif

  if !s:matcher.set(s:option.get_option('matcher'))
    return 0
  endif

  call s:option.source_option_set(a:options)
  let s:source_config = deepcopy(a:config)
  if !has_key(a:config, 'completefunc')
    let s:source_config.completefunc =
          \ {-> gram#set_items(s:source_config.items)}
    call s:option.source_option_add({'force_refresh': 0})
  endif
  if !has_key(a:config, 'hook')
    let s:source_config.hook = {}
  endif

  " Set default colors
  highlight default link gramMatch Number
  highlight default link gramSelected CursorLine

  " Re-initialize s:context
  let s:context.items = {'base': [], 'matched': []}

  try
    call s:invoke_hook('OpenWindowPre')
    call s:window.foreground()
    call s:invoke_hook('OpenWindowPost')
    call s:window.display_input_string('')
    call s:invoke_completefunc('')
    call s:draw_statusline()
    call s:getchar.start()
  catch
    call s:message.echomsg_error(v:exception)
    call s:window.background()
  finally

  return 1
endfunction

function! s:invoke_hook(kind) abort
  if has_key(s:source_config.hook, a:kind)
    call call(s:source_config.hook[a:kind], [])
  endif
endfunction

function! s:invoke_callback() abort
  if !empty(s:selected_item)
    call call(s:source_config.callback, [deepcopy(s:selected_item)])
  endif
  let s:selected_item = {}
  let s:source_config = {}
endfunction

function! s:_get_highlight_status(target) abort
  let output = substitute(execute('highlight ' .. a:target), "\n", '', 'g')
  let links_to = matchstr(output,
        \ printf('\C\<%s\>\s\+\<xxx\>\s\+links\s\+to\s\zs.\+', a:target))
  if links_to !=# ''
    return ['link', links_to]
  endif
  let arg = matchstr(output,
        \ printf('\C\<%s\>\s\+\<xxx\>\s\+\zs.\+', a:target))
  return ['color', arg]
endfunction

function! s:highlight_match(pattern) abort
  call s:window.highlight_match(a:pattern)
endfunction

function! s:_filter_all_items() abort
  call s:_set_completion([])
  let s:matcher_handler.items_queue = []
  call s:_trigger_matcher(s:context.items.base)
endfunction

function! s:set_items(items) abort
  let s:context.items.base = s:_standardize_items(a:items)
  call s:_filter_all_items()
endfunction

function! s:add_items(items) abort
  let items = s:_standardize_items(a:items)
  call extend(s:context.items.base, items)
  call s:_trigger_matcher(items)
endfunction

function! s:get_items(...) abort
  let kind = get(a:000, 0, '')
  if has_key(s:context.items, kind)
    return deepcopy(s:context.items[kind])
  else
    return deepcopy(s:context.items)
  endif
endfunction

function! s:is_active() abort
  return !empty(s:context)
endfunction

function! s:invoke_completefunc(input) abort
  call s:set_items([])
  call call(s:source_config.completefunc, [a:input])
endfunction

function! s:draw_statusline() abort
  call s:window.set_statusline(s:generate_statusline())
endfunction

function! s:generate_statusline() abort
  const modifiers = {
        \ '%n': get(s:source_config, 'name', "[No name]"),
        \ '%c': s:window.execute_func({-> line('$') - empty(gram#get_items('matched'))}),
        \ '%i': s:window.execute_func({-> line('.') - empty(gram#get_items('matched'))}),
        \ }
  return substitute(
        \ s:option.get_option('statusline'),
        \ join(keys(modifiers), '\|'),
        \ '\=modifiers[submatch(0)]',
        \ 'g'
        \ )
endfunction

function! s:on_input_changed(input) abort
  call s:matcher.invoke_on_input(a:input)
  if s:option.get_option('force_refresh')
    call s:invoke_completefunc(a:input)
  endif
  call s:window.display_input_string(a:input)
  call s:_filter_all_items()
endfunction

" Call matcher function asynchronously by using timer.
function! s:_trigger_matcher(items) abort
  if s:getchar.get_input() ==# ''
    call s:_pause_matcher()
    call s:_add_completion(a:items)
    return
  endif
  let s:matcher_handler.items_queue += deepcopy(a:items)
  if s:matcher_handler.timer_id == 0
    let s:matcher_handler.timer_id =
          \ timer_start(0, funcref('s:_call_matcher'), {'repeat': -1})
  else
    call timer_pause(s:matcher_handler.timer_id, 0)
  endif
endfunction

function! s:_call_matcher(timer) abort
  if empty(s:matcher_handler.items_queue) || !gram#is_active()
    call s:_pause_matcher()
    return
  endif

  let item = remove(s:matcher_handler.items_queue, 0)
  if s:matcher.invoke_matcher(item)
    call s:_add_completion([item])
  endif
endfunction

function! s:_pause_matcher() abort
  let s:matcher_handler.items_queue = []
  call timer_pause(s:matcher_handler.timer_id, 1)
endfunction

function! s:_set_completion(items) abort
  let s:context.items.matched = deepcopy(a:items)
  call s:window.replace_completion(
        \ s:_displize_items(s:context.items.matched))
endfunction

function! s:_add_completion(items) abort
  call s:window.add_completion(s:_displize_items(a:items))

  " Calling this must be at last because s:window.add_completion() checks if
  " the latest completion is empty or not by checking if
  " s:context.items.matched is empty or not.
  call extend(s:context.items.matched, deepcopy(a:items))
endfunction

function! s:_standardize_items(items) abort
  return map(deepcopy(a:items),
        \ {_, value -> extend(copy(s:item_skeleton),
        \   type(value) == v:t_string ? {'word': value} : value,
        \ 'force')})
endfunction

function! s:_displize_items(items) abort
  return map(deepcopy(a:items),
        \ {_, value -> value.abbr ==# '' ? value.word : value.abbr})
endfunction

if has('patch-8.1.1811')
  function! s:_set_window_color() abort
    highlight link _gramWindow_ Normal
  endfunction
else
  function! s:_set_window_color() abort
    " NOTE: Before the patch, setting 'wincolor' to 'Normal' didin't work.
    let target = 'Normal'
    while v:true
      let [kind, hl_arg] = s:_get_highlight_status(target)
      if kind ==# 'color'
        break
      endif
      " Got a highlight link. Try again.
      let target = hl_arg
    endwhile

    if hl_arg ==# 'cleared' || hl_arg ==# ''
      let hl_arg = 'NONE'
    endif

    execute 'highlight _gramWindow_' hl_arg
  endfunction
endif

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
