scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:window = gram#module#import('window')
  const s:null_input = {'text': '', 'col_idx': 0, 'text_save': ''}
  let s:input = copy(s:null_input)

  let s:_buf = {'winid': 0}
  function! s:_buf.create() abort
    if self.winid == 0
      let self.winid = popup_create('', {'callback': self.on_close})
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
    call self.execute('normal! ' .. a:keys)
  endfunction
  function! s:_buf.set_state(text, col) abort
    call self.execute([
          \ printf('call setline(1, %s)', string(a:text)),
          \ printf('call cursor(1, %s)', a:col)
          \ ])
  endfunction
  function! s:_buf.get_state() abort
    return eval(split(
          \ self.execute('echon {"text": getline(1), "col": col(".")}'),
          \ "\n")[0])
  endfunction
endfunction

function! s:__on_close__(idx) abort
  let s:input = copy(s:null_input)
  call s:_buf.close()
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
  call s:window.show_cursor(1)
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
  call s:_ex_normal('i' .. a:c ..
        \ "\<C-r>=\"\\\<lt>ESC>\" .. ['l', ''][col('.') == 1]\<CR>")
endfunction

function! s:_ex_normal(keys) abort
  let virtualedit_save = &virtualedit
  set virtualedit=onemore
  try
    call s:_buf.set_state(s:input.text, s:input.col_idx + 1)
    call s:_buf.ex_normal(a:keys)
    let state = s:_buf.get_state()
    let s:input.col_idx = state.col - 1
    let s:input.text = state.text
  finally
    let &virtualedit = virtualedit_save
  endtry
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
