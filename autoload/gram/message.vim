scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

function! s:_echo_base(command, color, msg) abort
  execute 'echohl' a:color
  execute a:command string(s:normalize_message(a:msg))
  echohl NONE
endfunction

function! s:_echo_color(color, msg) abort
  call s:_echo_base('echo', a:color, a:msg)
endfunction

function! s:_echomsg_color(color, msg) abort
  call s:_echo_base('echomsg', a:color, a:msg)
endfunction

function! s:normalize_message(msg) abort
  return '[gram] ' .. a:msg
endfunction

" Declarations of:
" - s:echo_error()
" - s:echo_warning()
" - s:echomsg_error()
" - s:echomsg_warning()
for [s:name, s:color] in [['error', 'Error'], ['warning', 'WarningMsg']]
  for s:cmd in ['echo', 'echomsg']
    execute printf("function! s:%s_%s(msg)\n", s:cmd, s:name) ..
          \ printf("call s:_%s_color(%s, a:msg)\n", s:cmd, string(s:color)) ..
          \ 'endfunction'
  endfor
endfor
unlet s:name s:color s:cmd

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
