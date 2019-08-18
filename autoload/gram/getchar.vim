scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:window = gram#module#import('window')
  const s:custom = gram#module#import('custom')
  const s:mapping = gram#module#import('mapping')
  const s:impl = gram#module#import('impl')
  const s:edit = gram#module#import('edit')
  const s:message = gram#module#import('message')

  " These mappings are defined with <expr>.
  const s:plugmaps = {
       \ 'j': '["j", "gg"][line(".") == line("$")]',
       \ 'k': '["k", "G"][line(".") == 1]',
       \ "\<CR>": printf('<SNR>%d__nmap_select()', s:SNR()),
       \ 'q': printf('<SNR>%d__nmap_quit()', s:SNR()),
       \ }

  let s:mode = 'n'
endfunction

function! s:__on_close__() abort
  let s:mode = 'n'
endfunction

function! s:SNR() abort
  return matchstr(expand('<sfile>'), '\zs<SNR>\zs\d\+_\zeSNR$')
endfunction

function! s:define_plugmaps() abort
  let cmd = map(items(s:plugmaps), {_, item ->
        \ printf('nnoremap <buffer> <expr> %s %s', item[0], item[1])})
  call s:window.execute(cmd)
endfunction

function! s:process() abort
  let input = []
  while getchar(1)
    let c = getchar()
    if type(c) == v:t_number
      let c = nr2char(c)
    endif
    call add(input, c)
  endwhile
  if empty(input)
    return
  endif
  call s:mapping.resolve(input)
  call s:impl.request_redraw()
endfunction

function! s:evaluate_keys(key_sequences) abort
  for key_sequence in a:key_sequences
    call s:_evaluate_keys_{s:mode}(key_sequence)
  endfor
endfunction

function! s:_evaluate_keys_n(keys) abort
  if a:keys ==# "\<C-c>"
    call s:window.background()
  else
    call s:_safe_feedkeys(a:keys)
  endif
endfunction

function! s:_evaluate_keys_i(keys) abort
  if a:keys ==# "\<C-c>"
    call s:cancel_insert()
  else
    call s:edit.insert_char(a:keys)
    if s:mode ==# 'i'
      call s:_insert_on_changed()
    endif
  endif
endfunction

function! s:_safe_feedkeys(keys) abort
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
" Workaround: Calling s:window.background() here occurs E315 Error.
" (Ref: https://github.com/vim-jp/issues/issues/1300)
" So, we call s:window.background() a bit later by using timer.
function! s:_nmap_select() abort
  call timer_start(0, funcref(
        \ 's:_callback_close_window', [s:window.execute_func({-> line('.') - 1})]
        \ ), {'repeat': 1})
  return ''
endfunction

function! s:_nmap_quit() abort
  call timer_start(0, funcref(
        \ 's:_callback_close_window', [-1]),
        \ {'repeat': 1})
  return ''
endfunction

function! s:_callback_close_window(selected_idx, timer_id) abort
  call s:window.background(a:selected_idx)
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
