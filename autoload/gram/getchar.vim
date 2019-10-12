scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:window = gram#module#import('window')
  const s:mapping = gram#module#import('mapping')
  const s:impl = gram#module#import('impl')
  const s:edit = gram#module#import('edit')
  const s:message = gram#module#import('message')

  " These mappings are defined with <expr>.
  const s:plugmaps = {
      \ 'j': s:_bind_func('_nmap_cursor_down()'),
      \ 'k': s:_bind_func('_nmap_cursor_up()'),
      \ "\<CR>": s:_bind_func('_nmap_select()'),
      \ 'q': s:_bind_func('_nmap_quit()'),
      \ 'p': s:_bind_func('_nmap_preview()'),
      \ }

  let s:mode = 'n'
  let s:key_queue = []
endfunction

function! s:__on_close__() abort
  let s:mode = 'n'
  let s:key_queue = []
  call s:_getchar.finish()
endfunction

if !exists('s:_getchar')
  let s:_getchar = {'winid': 0, 'is_active': 0}
endif
function! s:_getchar.start() abort
  if self.winid != 0
    call s:message.echomsg_warning('_getchar.start(): popup duplicates.')
    return
  endif
  let self.is_active = 1
  let self.winid = popup_create('', {
        \ 'mapping': 0,
        \ 'filter': self.filter,
        \ 'callback': self.callback,
        \ 'pos': 'center',
        \ 'mask': [[1, 1, 1, 1]],
        \ })
endfunction
function! s:_getchar.callback(winid, idx) abort
  let self.winid = 0
  if self.is_active
    call self.start()
    call self.safe_keytype_call('s:_feed_nomap_keys', [["\<C-c>"]])
  endif
endfunction
function! s:_getchar.filter(winid, char) abort
  call self.safe_keytype_call('s:_evaluate_keys', [[a:char]])
  call s:impl.draw_statusline()
  return 1
endfunction
function! s:_getchar.finish() abort
  let self.is_active = 0
  if self.winid != 0
    call popup_close(self.winid)
  endif
endfunction
function! s:_getchar.safe_keytype_call(function, args) abort
  " NOTE: Key inputs by :normal command are handled by filter.
  call popup_setoptions(self.winid, {'mapping': 1, 'filter': {-> 0}})
  call call(a:function, a:args)
  call popup_setoptions(self.winid, {'mapping': 0, 'filter': self.filter})
endfunction

function! s:_bind_func(func) abort
  return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\ze_bind_func$') ..
        \ a:func
endfunction

function! s:define_plugmaps() abort
  let cmd = map(items(s:plugmaps), {_, item ->
        \ printf('nnoremap <buffer> <expr> %s %s', item[0], item[1])})
  call s:window.execute(cmd)
endfunction

function! s:start() abort
  call s:_getchar.start()
endfunction

function! s:finish() abort
  call s:_getchar.finish()
endfunction

function! s:_evaluate_keys(inputs) abort
  call s:_evaluate_keys_impl(s:key_queue + a:inputs)
endfunction

function! s:_evaluate_keys_impl(inputs) abort
  let s:key_queue = []
  let queue = copy(a:inputs)

  while !empty(queue)
    let [rhs, queue] = s:_get_rhs(s:get_mode(), queue)
    let count = 0
    while rhs.kind ==# 'map'
      let count += 1
      if count > &maxmapdepth
        call s:message.echomsg_error('recursive mapping')
        return
      endif
      let [rhs, queue] = s:_get_rhs(s:get_mode(), rhs.key + queue)
    endwhile
    call s:_feed_nomap_keys(rhs.key)
  endwhile
endfunction

function! s:_get_rhs(mode, key_sequence) abort
  let node = s:mapping.get_usermap()[a:mode]
  let lhs_length = 0
  let rhs = {'data': {}, 'lhs_length': 0}
  let nomap = 1

  for key in a:key_sequence
    let lhs_length += 1
    if !has_key(node, key)
      break
    endif
    let nomap = 0
    let node = node[key]
    if type(node.rhs.key) != v:t_number
      let rhs.lhs_length = lhs_length
      let rhs.data = node.rhs
    endif
  endfor
  if nomap
    return [{'key': [a:key_sequence[0]], 'kind': 'noremap'},
          \ a:key_sequence[1 :]]
  elseif len(keys(node)) >= 2
    let s:key_queue = a:key_sequence
    return [{'key': [], 'kind': 'noremap'}, []]
  elseif empty(rhs.data)
    return [{'key': a:key_sequence[: lhs_length], 'kind': 'noremap'},
          \ a:key_sequence[lhs_length :]]
  endif
  return [rhs.data, a:key_sequence[rhs.lhs_length :]]
endfunction

function! s:_feed_nomap_keys(key_sequences) abort
  for key_sequence in a:key_sequences
    call s:_feed_nomap_keys_{s:mode}(key_sequence)
  endfor
endfunction

function! s:_feed_nomap_keys_n(keys) abort
  if a:keys ==# "\<C-c>"
    call s:window.background()
    return
  endif

  if a:keys ==# ''
    return
  endif

  let keys = a:keys
  if keys[0] ==# ' '  " See :h :normal
    let keys = '1' .. keys
  endif

  call s:window.setvar('&modifiable', 0)
  try
    call s:window.execute('normal ' .. keys)
  catch /^Vim\%((\a\+)\)\=:E21:/  " 'Cannot make changes' error.
    " TODO: Handle only entering insertmode.
    call s:start_insert()
  catch
    call s:message.echomsg_error(expand('<sfile>') .. v:exception)
  finally
    call s:window.setvar('&modifiable', 1)
  endtry
endfunction

function! s:_feed_nomap_keys_i(keys) abort
  if a:keys ==# "\<C-c>"
    call s:cancel_insert()
    return
  endif

  call s:edit.insert_char(a:keys)
  if s:mode ==# 'i'
    call s:_insert_on_changed()
  endif
endfunction

function! s:start_insert() abort
  let s:mode = 'i'
  call s:edit.start()
  return ''
endfunction

function! s:stop_insert() abort
  let s:mode = 'n'
  call s:edit.stop()
  return ''
endfunction

function! s:cancel_insert() abort
  let s:mode = 'n'
  call s:edit.cancel()
  call s:_insert_on_changed()
  return ''
endfunction

function! s:get_input() abort
  return s:edit.get_input_info('text')
endfunction

function! s:get_mode() abort
  return s:mode
endfunction

function! s:_insert_on_changed() abort
  let input = s:edit.get_input_info()
  call s:impl.on_input_changed(input.text)
endfunction


" --- Plugin default mappings ---
function! s:_lag_call(function, ...) abort
  let args = a:0 >= 1 ? a:1 : []
  call timer_start(0, {timer_id -> call(a:function, args)}, {'repeat': 1})
endfunction

" Workaround: Calling s:window.background() here occurs E315 Error.
" (Ref: https://github.com/vim-jp/issues/issues/1300)
" So, we call s:window.background() a bit later by using timer.
function! s:_nmap_select() abort
  call s:_lag_call(s:window.background,
        \ [s:window.execute_func({-> line('.') - 1})])
  return ''
endfunction

function! s:_nmap_quit() abort
  call s:_lag_call(s:window.background, [-1])
  return ''
endfunction

function! s:_nmap_preview() abort
  call s:_lag_call(s:impl.invoke_previewfunc)
  return ''
endfunction

function! s:_nmap_cursor_down() abort
  call s:_lag_call(s:impl.on_cursor_moved)
  if line('.') == line('$')
    return 'gg'
  endif
  return 'j'
endfunction

function! s:_nmap_cursor_up() abort
  call s:_lag_call(s:impl.on_cursor_moved)
  if line('.') == 1
    return 'G'
  endif
  return 'k'
endfunction


let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
