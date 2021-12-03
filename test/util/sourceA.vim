scriptversion 4

function! s:gather_candidates() abort
  return ['aaa', 'bbb', 'ccc']
endfunction

function! GetSourceA() abort
  return {'gather_candidates': funcref('gather_candidates')}
endfunction
