scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

if !exists('s:loaded')
  const s:NON_ESCAPED_SPACE = '\v%(%(\_^|[^\\])%(\\\\)*)@<=\s+'
  let s:matchers = []

  let s:loaded = v:true
endif

function! gram#source#matcher#multi_regexp#on_input(input) abort
  let s:matchers = filter(split(a:input, s:NON_ESCAPED_SPACE), 'v:val !=# ""')
  if empty(s:matchers)
    call gram#highlight_match('')
  else
    call gram#highlight_match('\c' .. join(s:matchers, '\|'))
  endif
endfunction

function! gram#source#matcher#multi_regexp#matcher(item) abort
  for matcher in s:matchers
    if a:item.word !~? matcher
      return 0
    endif
  endfor
  return 1
endfunction


let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
