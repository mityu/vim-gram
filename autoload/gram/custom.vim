scriptversion 4

function! gram#custom#map_action(mode, lhs, action_name, params = '') abort
  call gram#mapping#noremap(a:mode, a:lhs, a:action_name .. '%' .. a:params)
endfunction

function! gram#custom#noremap_keys(mode, lhs, rhs) abort
  call gram#mapping#noremap(a:mode, a:lhs, a:rhs)
endfunction

function! gram#custom#map_keys(mode, lhs, rhs) abort
  call gram#mapping#map(a:mode, a:lhs, a:rhs)
endfunction
