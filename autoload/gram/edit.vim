scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim


function! s:__init__() abort
  const s:window = gram#module#import('window')
  const s:getchar = gram#module#import('getchar')
  const s:null_input = {'text': '', 'col': 1, 'text_save': ''}
  let s:input = copy(s:null_input)
  const s:plug_ESC = printf("\<C-r>=<SNR>%d__plug_ESC()\<CR>", s:_SNR())

  let s:_buf = {'winid': 0}
  function! s:_buf.create() abort
    if self.winid == 0
      let self.winid = popup_create('', {'callback': self.on_close})
      call popup_hide(self.winid)

      " Built-in <ESC>
      call self.execute('inoremap <buffer> <Plug>(ESC) <ESC>')

      " <ESC> for plugin
      call self.execute('inoremap <buffer> <expr> <ESC> ' ..
            \ string(get(s:getchar.stop_insert, 'func')) .. '()')

      " Type <CR> to decide input.
      call self.execute('imap <buffer> <CR> <ESC>')
    endif
  endfunction
  function! s:_buf.close() abort
    call popup_close(self.winid)
  endfunction
  function! s:_buf.on_close(winid, idx) abort
    let self.winid = 0
  endfunction
  function! s:_buf.execute(cmd) abort
    let eventignore_save = &eventignore
    set eventignore=all
    try
      return win_execute(self.winid, a:cmd)
    finally
      let &eventignore = eventignore_save
    endtry
  endfunction
  function! s:_buf.ex_normal(keys) abort
    call self.execute([
          \ printf('call setline(1, %s)', string(s:input.text)),
          \ printf('call cursor(1, %s)', s:input.col),
          \ 'normal ' .. a:keys
          \ ])
  endfunction
endfunction

function! s:__on_close__() abort
  let s:input = copy(s:null_input)
  call s:_buf.close()
endfunction

function! s:_SNR() abort
  return matchstr(expand('<sfile>'), '\zs<SNR>\zs\d\+_\ze_SNR$')
endfunction

function! s:get_input_info(...) abort
  if empty(a:000)
    return copy(s:input)
  else
    return s:input[a:1]
  endif
endfunction

function! s:start() abort
  let s:input.text_save = s:input.text
  call s:show_cursor()
  call s:_buf.create()
endfunction

function! s:stop() abort
  let s:input.text_save = ''
  call s:window.hide_cursor()
endfunction

function! s:cancel() abort
  let s:input.text = s:input.text_save
  call s:stop()
endfunction

function! s:insert_char(c) abort
  call s:_ex_normal('i' .. a:c .. s:plug_ESC)
  call s:show_cursor()
endfunction

function! s:_plug_ESC() abort
  let s:input.text = getline(1)
  let s:input.col = col('.')
  return "\<Plug>(ESC)"
endfunction

function! s:show_cursor() abort
  if s:getchar.get_mode() ==# 'i'
    call s:window.show_cursor(s:input.col)
  endif
endfunction

function! s:_ex_normal(keys) abort
  let virtualedit_save = &virtualedit
  set virtualedit=onemore
  try
    call s:_buf.ex_normal(a:keys)
  finally
    let &virtualedit = virtualedit_save
  endtry
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
