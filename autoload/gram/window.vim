scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:null_winID = 0
  let s:completion_winID = s:null_winID
  let s:prompt_winID = s:null_winID
  let s:match_id = {
        \ 'cursor': -1,
        \ 'highlight': -1
        \ }
  let s:cursor_line = 1

  const s:message = gram#module#import('message')
  const s:GetOption = gram#module#import('option').get_option

  const s:PopupHeight = {-> min([max([&lines * 3 / 4, 35]), &lines - 6])}
  const s:PopupWidth = {-> min([max([&columns / 2, 90]), &columns])}
  const s:completion_options = {
        \ 'pos': {-> 'topleft'},
        \ 'drag': {-> 0},
        \ 'scrollbar': {-> 0},
        \ 'padding': {-> [0, 0, 0, 0]},
        \ 'border': {-> [0, 1, 1, 1]},
        \ 'borderchars': {-> [' ']},
        \ 'borderhighlight': {-> ['gramWindowBorder']},
        \ 'callback': {-> 'gram#module#on_close'},
        \ 'cursorline': {-> 0},
        \ 'highlight': {-> 'gramWindow'},
        \ 'zindex': {-> 100},
        \ }
  const s:prompt_options = {
        \ 'pos': {-> 'topleft'},
        \ 'drag': {-> 0},
        \ 'border': {-> [1, 1, 0, 1]},
        \ 'borderchars': {-> [' ']},
        \ 'borderhighlight': {-> ['gramWindowBorder']},
        \ 'cursorline': {-> 0},
        \ 'highlight': {-> 'gramWindow'},
        \ 'zindex': {-> 100},
        \ 'minheight': {-> 1},
        \ 'maxheight': {-> 1},
        \ 'title': {-> ''},
        \ }

  call sign_define('gramCursorline', {'text': '>', 'linehl': 'Cursorline'})
endfunction

function! s:__on_close__() abort
  " Cleawn up matches.
  call s:_matchdelete(s:match_id.cursor, s:prompt_winID)
  call s:_matchdelete(s:match_id.highlight, s:completion_winID)
  call popup_close(s:prompt_winID)
  call s:set_cursor_line(1)

  augroup gram-window
    autocmd!
  augroup END
endfunction

function! s:foreground() abort
  let s:completion_winID =
        \ popup_create('', map(deepcopy(s:completion_options), 'v:val()'))
  let s:prompt_winID =
        \ popup_create('', map(deepcopy(s:prompt_options), 'v:val()'))

  " Set additional options.
  call s:_adjust_position()

  augroup gram-window
    autocmd!
    autocmd VimResized * call s:_adjust_position()
  augroup END
endfunction

function! s:background(...) abort
  if s:completion_winID == s:null_winID
    call s:message.echomsg_error('Window not found')
    return
  endif
  call popup_close(s:completion_winID, get(a:000, 0, -1))
endfunction

function! s:_adjust_position() abort
  let width = s:PopupWidth()
  let height = s:PopupHeight()
  let line = (&lines - height) / 2
  let col = (&columns - width) / 2

  call popup_move(s:completion_winID, {
        \ 'line': line,
        \ 'col': col,
        \ 'maxwidth': width,
        \ 'minwidth': width,
        \ 'maxheight': height,
        \ 'minheight': height,
        \ })
  call popup_move(s:prompt_winID, {
        \ 'line': line - 2,
        \ 'col': col,
        \ 'minwidth': width,
        \ 'maxwidth': width,
        \ 'maxheight': 1,
        \ 'minheight': 1,
        \ })

endfunction

function! s:display_input_string(input) abort
  " Add a space at the end of input to enable to show cursor when it's at the
  " end of input (matchadd(), matchaddpos(), or text-properties can't
  " highlight the end of line on popup-windows).
  call setbufline(winbufnr(s:prompt_winID), 1,
        \ s:GetOption('prompt') .. a:input .. ' ')
endfunction

function! s:hide_cursor() abort
  if s:match_id.cursor != 0
    call s:_matchdelete(s:match_id.cursor, s:prompt_winID)
  endif
endfunction

function! s:show_cursor(col) abort
  call s:hide_cursor()
  let s:match_id.cursor = matchaddpos(
        \ '_gramCursor_',
        \ [[1, a:col + strlen(s:GetOption('prompt'))]],
        \ 10, s:match_id.cursor, {'window': s:prompt_winID})
endfunction

function! s:set_statusline(statusline) abort
  call popup_setoptions(s:prompt_winID, {'title': a:statusline})
endfunction

function! s:get_winID() abort
  return s:completion_winID
endfunction

function! s:get_bufnr() abort
  if s:completion_winID == s:null_winID
    return 0
  endif
  return winbufnr(s:completion_winID)
endfunction

function! s:setline(line, expr) abort
  call call('setbufline', [s:get_bufnr(), a:line, a:expr])
endfunction

function! s:append(line, expr) abort
  call call('appendbufline', [s:get_bufnr(), a:line, a:expr])
endfunction

function! s:deleteline(first, ...) abort
  silent call call('deletebufline', [s:get_bufnr(), a:first] + a:000)
endfunction

function! s:_matchdelete(match_id, winid) abort
  if a:match_id == -1
    return
  endif
  for info in getmatches(a:winid)
    if info.id == a:match_id
      call matchdelete(a:match_id, a:winid)
      return
    endif
  endfor
endfunction

function! s:highlight_match(pattern) abort
  call s:_matchdelete(s:match_id.highlight, s:completion_winID)
  if a:pattern ==# ''
    return
  endif
  try
    let s:match_id.highlight = matchadd(
          \ 'gramMatch', a:pattern, 10, s:match_id.highlight,
          \ {'window': s:completion_winID})
  catch
    " Ignore.
  endtry
endfunction

function! s:delete_completion() abort
  call s:deleteline(1, '$')
endfunction

function! s:replace_completion(items) abort
  call s:delete_completion()
  call s:setline(1, a:items)
  call s:execute_func({-> cursor(1, 0)})
endfunction

function! s:add_completion(items) abort
  if empty(gram#get_items('matched'))
    call s:setline(1, a:items)
  else
    call s:append('$', a:items)
  endif
endfunction

function! s:execute_func(Funcref) abort
  let eventignore_save = &eventignore
  set eventignore=all
  try
    let rettv = 0
    call win_execute(s:get_winID(), 'let rettv = a:Funcref()')
    return rettv
  finally
    let &eventignore = eventignore_save
  endtry
endfunction

function! s:execute(cmd) abort
  return s:execute_func(function('execute', [a:cmd]))
endfunction

function! s:setvar(name, val) abort
  return setwinvar(s:get_winID(), a:name, a:val)
endfunction

function! s:getvar(name, ...) abort
  return call('getwinvar', [s:get_winID(), a:name] + a:000)
endfunction

function! s:set_cursor_line(line) abort
  " TODO: implement scroll
  let s:cursor_line = a:line
  call sign_unplace('PopUpMenu', {'buffer': s:get_bufnr()})
  call sign_place(0, 'PopUpMenu', 'gramCursorline', s:get_bufnr(), {'lnum': a:line})
endfunction

function! s:line(expr) abort
  if a:expr ==# '.'
    return s:cursor_line
  endif
  return line(a:expr, s:get_winID())
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
