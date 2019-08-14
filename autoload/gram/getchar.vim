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

  const s:plugmaps = {
       \ 'j': {-> s:_nmap_cursor(v:count1)},
       \ 'k': {-> s:_nmap_cursor(-v:count1)},
       \ "\<CR>": 's:_nmap_select',
       \ 'q': 's:_nmap_quit',
       \ }

  let s:mode = 'n'
  let s:queue = []
endfunction

function! s:__on_close__(idx) abort
  let s:mode = 'n'
endfunction

function! s:initialize() abort
  call s:window.execute_func({-> s:_initialize_impl()})
endfunction
function! s:_initialize_impl() abort
  nmapclear <buffer>
  let maps = map(split(execute('nmap'), "\n"),
        \ {_, line -> {map -> printf('nnoremap <buffer> %s %s', map, map)}
        \ (matchstr(line, '^n\a*\s\+\zs.\+\ze\s\+'))})
  execute join(maps, "\n")
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
  if index(['i', 'a', 'o'], a:keys) != -1
    call s:start_insert()
  elseif a:keys ==# "\<C-c>"
    call s:window.background()
  elseif has_key(s:plugmaps, a:keys)
    call call(s:plugmaps[a:keys], [])
  else
    call s:_safe_feedkeys(a:keys)
  endif
endfunction

function! s:_evaluate_keys_i(keys) abort
  if a:keys ==# "\<ESC>"
    call s:stop_insert()
  elseif a:keys ==# "\<C-c>"
    call s:cancel_insert()
  else
    call s:edit.insert_char(a:keys)
    call s:_insert_on_changed()
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
    " Ignore.
  catch
    call s:message.echomsg_error(expand('<sfile>') .. v:exception)
  finally
    call s:window.setvar('&modifiable', 1)
  endtry
endfunction

function! s:start_insert() abort
  let s:mode = 'i'
  call s:edit.start()
endfunction

function! s:stop_insert() abort
  let s:mode = 'n'
  call s:edit.stop()
endfunction

function! s:cancel_insert() abort
  let s:mode = 'n'
  call s:edit.cancel()
  call s:_insert_on_changed()
endfunction

function! s:get_input() abort
  return s:edit.get_input_info('text')
endfunction

function! s:get_mode() abort
  return s:mode
endfunction

function! s:_insert_on_changed() abort
  let input = s:edit.get_input_info()
  call s:impl.on_input_changed(input.text, input.col_idx + 1)
endfunction


" --- Plugin default mappings ---
function! s:_nmap_cursor(count) abort
  call s:window.execute_func({-> s:_nmap_cursor_impl(a:count)})
endfunction
function! s:_nmap_cursor_impl(count) abort
  let mod = line('$')
  let line = line('.') - 1 + a:count
  if line < 0
    let line += ((-line / mod) + 1) * mod
  endif
  let line = line % mod + 1
  call cursor(line, 0)
endfunction

function! s:_nmap_select() abort
  call s:window.background(s:window.execute_func({-> line('.') - 1}))
endfunction

function! s:_nmap_quit() abort
  call s:window.background()
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
