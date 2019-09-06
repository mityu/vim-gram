scriptversion 3
let s:cpoptions_save = &cpoptions
set cpoptions&vim

const s:parent_dir = fnamemodify(expand('<sfile>:h'), ':p')
const s:scriptlocal = vital#gram#new().import('Vim.ScriptLocal')

if !exists('s:modules')
  let s:modules = {}
  let s:module_callbacks = {}
endif

" A simple module loading function.
" Example: Load modules of autoload/gram/module.vim:
"   let s:module = gram#module#import('module')
function! gram#module#import(name) abort
  if !has_key(s:modules, a:name)
    let s:modules[a:name] =
          \ s:scriptlocal.sfuncs(s:parent_dir .. a:name .. '.vim')

    " Store __init__() temporally.  It must be called on the last of this
    " block.
    let Initializer = v:null
    if has_key(s:modules[a:name], '__init__')
      let Initializer = s:modules[a:name].__init__
    endif

    " Store __on_close__()
    if has_key(s:modules[a:name], '__on_close__')
      let s:module_callbacks[a:name] = s:modules[a:name].__on_close__
    endif

    let s:modules[a:name] = filter(s:modules[a:name],
          \ {key, val -> key[0] !=# '_'})

    " Call initializer function
    if type(Initializer) == v:t_func
      call Initializer()
    endif
  endif
  return copy(s:modules[a:name])
endfunction

function! gram#module#on_close(winid, selected_idx) abort
  call gram#module#import('impl').set_selected_item(a:selected_idx)

  for Callback in values(s:module_callbacks)
    call Callback()
  endfor

  call gram#module#import('impl').invoke_callback()
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
