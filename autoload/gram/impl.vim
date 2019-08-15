scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:custom = gram#module#import('custom')
  const s:getchar = gram#module#import('getchar')
  const s:message = gram#module#import('message')
  const s:window = gram#module#import('window')
  const s:matcher = gram#module#import('matcher')

  const s:item_skeleton =
        \ {'word': '', 'abbr': '', 'menu': '', 'user_data': ''}

  let s:default_option = {}
  let s:context = {}
  let s:source_config = {}
  let s:need_redraw = v:false
  let s:matcher_handler = {'timer_id': 0, 'items_queue': []}
  let s:selected_item = {}
endfunction

function! s:__on_close__(selected_idx) abort
  if a:selected_idx >= 0
    let s:selected_item = s:context.items.matched[a:selected_idx]
  else
    let s:selected_item = {}
  endif
  let s:context = {}
  call s:custom.remove_source_options()
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

  let requirements = ['completefunc']
  let entries = keys(a:config)
  let missing_entries = filter(requirements, 'index(entries, v:val) == -1')
  if !empty(missing_entries)
    call s:message.echomsg_error(
          \ 'Not enough config entries: Missing ' .. string(missing_entries))
    return
  endif

  if !s:matcher.set(s:custom.get_option('matcher'))
    return
  endif

  for [key, Value] in items(a:config)  " 'Value' might be Funcref.
    let s:source_config[key] = Value
  endfor
  call s:custom.set_source_options(a:options)

  " Set default colors
  highlight default link gramMatch Number
  highlight default link gramSelected CursorLine

  " Re-initialize s:context
  let s:context.items = {'base': [], 'matched': []}

  call s:window.foreground()
  call s:window.display_input_string('')
  call s:invoke_completefunc('')
  redraw!

  call inputsave()
  try
    call s:_main_loop()  " Loop until selecting is canceled/finished.
  catch
    call s:message.echomsg_error(expand('<sfile>') .. v:exception)
  endtry

  call inputrestore()
  call s:window.background()

  try
    return deepcopy(s:selected_item)
  finally
    let s:selected_item = {}  " Clear selected item
  endtry
endfunction

function! s:_main_loop() abort
  while s:is_active()
    try
      call s:getchar.process()
      call s:window.set_statusline(s:generate_statusline())
      if s:need_redraw
        redraw!
        let s:need_redraw = v:false
      endif
      sleep 75m  " Let timers/jobs work.
    catch /^Vim:Interrupt$/
      call s:getchar.evaluate_keys(["\<C-c>"])
    endtry
  endwhile
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

function! s:set_items(items) abort
  let s:context.items.base = s:_standardize_items(a:items)
  call s:_set_completion([])
  call s:_trigger_matcher(s:context.items.base)
endfunction

function! s:add_items(items) abort
  let items = s:_standardize_items(a:items)
  call extend(s:context.items, items)
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
  call call(s:source_config.completefunc, [a:input])
endfunction

function! s:generate_statusline() abort
  const modifiers = {
        \ '%n': get(s:source_config, 'name', "[No name]"),
        \ '%c': s:window.execute_func({-> line('$') - empty(gram#get_items('matched'))}),
        \ '%i': s:window.execute_func({-> line('.') - empty(gram#get_items('matched'))}),
        \ }
  return substitute(
        \ s:custom.get_option('statusline'),
        \ join(keys(modifiers), '\|'),
        \ '\=modifiers[submatch(0)]',
        \ 'g'
        \ )
endfunction

function! s:on_input_changed(input) abort
  call s:matcher.invoke_on_input(a:input)
  if s:custom.get_option('force_refresh')
    call s:invoke_completefunc(a:input)
  endif
  call s:window.display_input_string(a:input)
  call s:_trigger_matcher(s:get_items('base'))
endfunction

function! s:request_redraw() abort
  let s:need_redraw = v:true
endfunction

" Call matcher function asynchronously by using timer.
function! s:_trigger_matcher(items) abort
  if s:getchar.get_input() ==# ''
    call s:_set_completion(a:items)
    return
  endif
  call s:_set_completion([])
  let s:matcher_handler.items_queue = deepcopy(a:items)
  if s:matcher_handler.timer_id == 0
    let s:matcher_handler.timer_id =
          \ timer_start(0, 's:_call_matcher', {'repeat': -1})
  else
    call timer_pause(s:matcher_handler.timer_id, 0)
  endif
endfunction

function! s:_call_matcher(timer) abort
  if empty(s:matcher_handler.items_queue) || !gram#is_active()
    call timer_pause(s:matcher_handler.timer_id, 1)
    return
  endif

  let item = remove(s:matcher_handler.items_queue, 0)
  if s:matcher.invoke_matcher(item)
    call s:_add_completion(item)
  endif
endfunction

function! s:_set_completion(items) abort
  let s:context.items.matched = deepcopy(a:items)
  call s:window.replace_completion(
        \ s:_displize_items(s:context.items.matched))
endfunction

function! s:_add_completion(item) abort
  call s:window.add_completion(s:_displize_items([a:item]))

  " Calling this must be at last because s:window.add_completion() checks if
  " the latest completion is empty or not by checking if
  " s:context.items.matched is empty or not.
  call add(s:context.items.matched, deepcopy(a:item))
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

function! s:_set_window_color() abort
  " NOTE: Linking gramMenu to Normal doesn't work because set "Normal" to
  " 'wincolor' option has no effects.
  let target = 'Normal'
  while v:true
    let [kind, hl_arg] = s:_get_highlight_status(target)
    if kind ==# 'color'
      break
    endif
    " Got a highlight link. Try again.
    let target = hl_arg
  endwhile
  execute 'highlight _gramWindow_' hl_arg
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
