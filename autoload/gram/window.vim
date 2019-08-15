scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:__init__() abort
  const s:null_winID = 0
  let s:completion_winID = s:null_winID
  let s:prompt_winID = s:null_winID
  let s:match_id = {
        \ 'cursor': 0,
        \ 'highlight': 0
        \ }

  const s:message = gram#module#import('message')
  const s:GetOption = gram#module#import('custom').get_option
  const s:RequestRedraw = gram#module#import('impl').request_redraw

  const s:PopupHeight = {-> min([max([&lines * 3 / 4, 35]), &lines - 3])}
  const s:PopupWidth = {-> min([max([&columns / 2, 90]), &columns])}
  const s:completion_options = {
        \ 'pos': {-> 'center'},
        \ 'drag': {-> 0},
        \ 'border': {-> [0, 0, 0, 0]},
        \ 'callback': {-> 'gram#module#on_close'},
        \ 'cursorline': {-> 0},
        \ 'highlight': {-> '_gramWindow_'},
        \ 'zindex': {-> 100},
        \ 'minheight': s:PopupHeight,
        \ 'maxheight': s:PopupHeight,
        \ 'minwidth': s:PopupWidth,
        \ 'maxwidth': s:PopupWidth,
        \ }
  const s:prompt_options = {
        \ 'pos': {-> 'topleft'},
        \ 'drag': {-> 0},
        \ 'border': {-> [0, 0, 0, 0]},
        \ 'cursorline': {-> 0},
        \ 'highlight': {-> '_gramWindow_'},
        \ 'zindex': {-> 100},
        \ 'minheight': {-> 1},
        \ 'maxheight': {-> 1},
        \ 'minwidth': s:PopupWidth,
        \ 'maxwidth': s:PopupWidth,
        \ 'title': {-> 'statusline'},
        \ }
endfunction

function! s:__on_close__(selected_idx) abort
  " Cleawn up matches.
  call s:_matchdelete('cursor', s:prompt_winID)
  call s:_matchdelete('highlight', s:completion_winID)
  call popup_close(s:prompt_winID)
endfunction

function! s:foreground() abort
  let s:completion_winID =
        \ popup_create([''], map(deepcopy(s:completion_options), 'v:val()'))
  let s:prompt_winID =
        \ popup_create('', map(deepcopy(s:prompt_options), 'v:val()'))

  let pos = popup_getpos(s:completion_winID)
  call popup_move(s:prompt_winID,
        \ {'line': pos.line - 2, 'col': pos.col})

  call s:setvar('&cursorline', 1)
  call gram#module#import('getchar').define_plugmaps()
endfunction

function! s:background(...) abort
  if s:completion_winID == s:null_winID
    call s:message.echomsg_error('Window not found')
    return
  endif
  call popup_close(s:completion_winID, get(a:000, 0, -1))
endfunction

function! s:display_input_string(input) abort
  " Add a space at the end of input to enable to show cursor when it's at the
  " end of input (matchadd(), matchaddpos(), or text-properties can't
  " highlight the end of line on popup-windows).
  call setbufline(winbufnr(s:prompt_winID), 1,
        \ s:GetOption('prompt') .. a:input .. ' ')
  call s:RequestRedraw()
endfunction

function! s:hide_cursor() abort
  if s:match_id.cursor != 0
    call s:_matchdelete('cursor', s:prompt_winID)
  endif
endfunction

function! s:show_cursor(col) abort
  call s:hide_cursor()
  let s:match_id.cursor = matchaddpos(
        \ '_gramCursor_',
        \ [[1, a:col + strlen(s:GetOption('prompt'))]],
        \ 10, -1, {'window': s:prompt_winID})
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
  call s:RequestRedraw()
endfunction

function! s:append(line, expr) abort
  call call('appendbufline', [s:get_bufnr(), a:line, a:expr])
  call s:RequestRedraw()
endfunction

function! s:deleteline(first, ...) abort
  call call('deletebufline', [s:get_bufnr(), a:first] + a:000)
  call s:RequestRedraw()
endfunction

function! s:_matchdelete(kind, winid) abort
  if s:match_id[a:kind] == 0
    return
  endif
  call matchdelete(s:match_id[a:kind], a:winid)
  let s:match_id[a:kind] = 0
endfunction

function! s:highlight_match(pattern) abort
  if s:match_id.highlight != 0
    call s:_matchdelete('highlight', s:completion_winID)
  endif
  if a:pattern ==# ''
    return
  endif
  try
    let s:match_id.highlight = matchadd(
          \ 'gramMatch', a:pattern, 10, -1, {'window': s:completion_winID})
  catch
    " Ignore.
  endtry
  call s:RequestRedraw()
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
    call win_execute(s:get_winID(), 'let s:execute_rettv = a:Funcref()')
    return s:execute_rettv
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

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
