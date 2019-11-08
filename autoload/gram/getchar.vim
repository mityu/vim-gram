scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:window = gram#module#import('window')
  const s:mapping = gram#module#import('mapping')
  const s:impl = gram#module#import('impl')
  const s:message = gram#module#import('message')
  const s:insertmode = gram#module#import('insertmode')

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
    call s:got_ctrl_c()
  endif
endfunction
function! s:_getchar.filter(winid, char) abort
  call s:_evaluate_keys([a:char])
  if gram#is_active()
    call s:impl.draw_statusline()
  endif
  return 1
endfunction
function! s:_getchar.finish() abort
  let self.is_active = 0
  if self.winid != 0
    call popup_close(self.winid)
  endif
endfunction

function! s:start() abort
  call s:_getchar.start()
endfunction

function! s:finish() abort
  call s:_getchar.finish()
endfunction

function! s:got_ctrl_c() abort
  let s:key_queue = []
  call s:_feed_nomap_keys(["\<C-c>"])
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

    if rhs.kind ==# 'wait_more_keys'
      " Do nothing.
    elseif rhs.kind ==# 'noremap'
      call s:_feed_nomap_keys(rhs.key)
    elseif rhs.kind ==# 'action'
      for action_name in rhs.key
        let Func = s:mapping.get_action_function_from_action_name(
              \ s:get_mode(), action_name)
        if type(Func) != v:t_number
          call call(Func, [])
        endif
      endfor
    else
      call s:message.echoerr_msg('Unknown rhs.kind: ' .. rhs.kind)
    endif
  endwhile

  " TODO: Put on better place
  if s:get_mode() ==# 'i'
    call s:_insert_on_changed()
  endif
endfunction

function! s:_get_rhs(mode, key_sequence) abort
  let node = s:mapping.get_usermap()[a:mode]
  let lhs_length = 0
  let rhs = {'data': {}, 'lhs_length': 0}

  " Search the rhs tree to check if mapping exists or not.
  for key in a:key_sequence
    let lhs_length += 1
    " NOTE: Some special keys is expressed with two or more characters, (for
    " example, "\<Del>" will be "<80>kD".) and they're separated into each
    " char when register mapping.  Therefore, if we got a such character, we
    " separate it into each character and then check if mapping exists.
    if strlen(key) == 1
      if !has_key(node, key)
        break
      endif
      let node = node[key]
    else
      let node_save = node
      for char in split(key, '\zs')
        if !has_key(node, char)
          let node = node_save
          break
        endif
        let node = node[char]
      endfor
    endif
    if type(node.rhs.key) != v:t_number
      let rhs.lhs_length = lhs_length
      let rhs.data = node.rhs
    endif
  endfor

  let mapping_not_found = empty(rhs.data)
  let cannot_decide_single_mapping = len(keys(node)) >= 2

  if cannot_decide_single_mapping && !mapping_not_found
    " Wait for more keys typed.
    let s:key_queue = a:key_sequence
    return [{'key': [], 'kind': 'wait_more_keys'}, []]
  elseif mapping_not_found
    return [{'key': a:key_sequence[: lhs_length], 'kind': 'noremap'},
          \ a:key_sequence[lhs_length :]]
  else
    return [rhs.data, a:key_sequence[rhs.lhs_length :]]
  endif
endfunction

function! s:_feed_nomap_keys(key_sequences) abort
  for key_sequence in a:key_sequences
    call s:_feed_nomap_keys_{s:mode}(key_sequence)
  endfor
endfunction

function! s:_feed_nomap_keys_n(keys) abort
  " Ignore all key types in normal-mode except for CTRL-C.
  if a:keys ==# "\<C-c>"
    call s:window.background()
  endif
endfunction

function! s:_feed_nomap_keys_i(keys) abort
  if a:keys ==# "\<C-c>"
    call s:cancel_insert()
    return
  endif

  " Ignore special keys that its keycode starts with 0x80 in Vim like <BS>,
  " <Del>, <Up>, etc.
  if a:keys =~# "^\x80"
    return
  endif

  call s:insertmode.insert_string(a:keys)
endfunction

function! s:get_input() abort
  return s:insertmode.get_input_text()
endfunction

function! s:get_mode() abort
  return s:mode
endfunction

function! s:_insert_on_changed() abort
  call s:impl.on_input_changed(s:get_input(),
        \ s:insertmode.get_cursor_idx() + 1)
endfunction



" Default actions
function! s:start_insert() abort
  let s:mode = 'i'
  call s:insertmode.start_insert()
  return ''
endfunction

function! s:stop_insert() abort
  let s:mode = 'n'
  call s:insertmode.stop_insert()
  return ''
endfunction

function! s:cancel_insert() abort
  let s:mode = 'n'
  call s:insertmode.cancel_insert()
  call s:_insert_on_changed()
  return ''
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
