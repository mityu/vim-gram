scriptversion 4

let s:timer = {'timerID': 0}

function! s:timer.is_running() abort
  return !empty(timer_info(self.timerID))
endfunction

function! s:timer.stop() abort
  if self.is_running()
    call timer_stop(self.timerID)
  endif
endfunction

function! s:timer.pause() abort
  call timer_pause(self.timerID, 1)
endfunction

function! s:timer.resume() abort
  call timer_pause(self.timerID, 0)
endfunction

function! s:timer.getID() abort
  return self.timerID
endfunction

function! gram#timer#start(time, Callback, options = {}) abort
  let timer = deepcopy(s:timer)
  let timer.timerID = timer_start(a:time, a:Callback, a:options)
  return timer
endfunction

function! gram#timer#null() abort
  return deepcopy(s:timer)
endfunction
