"=============================================================================
" File: comfortable_motion.vim
" Author: Yuta Taniguchi
" Created: 2016-10-02
"=============================================================================

scriptencoding utf-8

if !exists('g:loaded_comfortable_motion')
    finish
endif
let g:loaded_comfortable_motion = 1

let s:save_cpo = &cpo
set cpo&vim


" Default parameter values
if !exists('g:comfortable_motion_interval')
  let g:comfortable_motion_interval = 1000.0 / 60
endif
if !exists('g:comfortable_motion_friction')
  let g:comfortable_motion_friction = 80.0
endif
if !exists('g:comfortable_motion_air_drag')
  let g:comfortable_motion_air_drag = 2.0
endif
if !exists('g:comfortable_motion_scroll_down_key')
  let g:comfortable_motion_scroll_down_key = "\<C-e>"
endif
if !exists('g:comfortable_motion_scroll_up_key')
  let g:comfortable_motion_scroll_up_key = "\<C-y>"
endif

" The state
let s:comfortable_motion_state = {
\ 'impulse': 0.0,
\ 'velocity': 0.0,
\ 'delta': 0.0,
\ 'air_drag' : 0.0,
\ }

function! s:tick(timer_id)

  let l:st = s:comfortable_motion_state  " This is just an alias for the global variable
  if abs(l:st.velocity) >= 1 || l:st.impulse != 0 " short-circuit if velocity is less than one
    let l:dt = g:comfortable_motion_interval / 1000.0  " Unit conversion: ms -> s

    " Compute resistance forces
    let l:vel_sign = l:st.velocity == 0
      \            ? 0
      \            : l:st.velocity / abs(l:st.velocity)
    let l:friction = -l:vel_sign * g:comfortable_motion_friction * 1  " The mass is 1
    let l:air_drag = -l:st.velocity * l:st.air_drag
    let l:additional_force = l:friction + l:air_drag

    " Update the state
    let l:st.delta += l:st.velocity * l:dt
    let l:st.velocity += l:st.impulse + (abs(l:additional_force * l:dt) > abs(l:st.velocity) ? -l:st.velocity : l:additional_force * l:dt)
    let l:st.impulse = 0

    " Current Position
    let l:topline = line('w0')
    let l:botline = line('w$')

    " Scroll
    let l:int_delta = float2nr(l:st.delta >= 0 ? floor(l:st.delta) : ceil(l:st.delta))
    let l:st.delta -= l:int_delta
    if l:int_delta > 0
      if l:botline == line("$") " when can see bottom line, move cursor
        execute "normal! " . string(abs(l:int_delta)) . "j"
      else
        execute "normal! " . string(abs(l:int_delta)) . g:comfortable_motion_scroll_down_key
      endif
    elseif l:int_delta < 0
      if l:topline == 1
        execute "normal! " . string(abs(l:int_delta)) . "k"
      else
        execute "normal! " . string(abs(l:int_delta)) . g:comfortable_motion_scroll_up_key
      endif
    else
      " Do nothing
    endif
    redraw

    " stop at the top and bottom
    let l:pos = getpos('.')
    if ( l:pos[1] == 1 && l:st.velocity < 0 )
      \ || ( l:pos[1] == line('$') && l:st.velocity > 0 )
      let l:st.velocity = 0
      let l:st.delta = 0
    endif
  else
    " Stop scrolling and the thread
    let l:st.velocity = 0
    let l:st.delta = 0
    call timer_stop(s:timer_id)
    unlet s:timer_id
  endif
endfunction

function! comfortable_motion#flick_impl(impulse, air_drag)
  let l:st = s:comfortable_motion_state  " This is just an alias for the global variable
  let l:st.air_drag = a:air_drag
  if !exists('s:timer_id')
    " There is no thread, start one
    let l:interval = float2nr(round(g:comfortable_motion_interval))
    let s:timer_id = timer_start(l:interval, function("s:tick"), {'repeat': -1})
  endif

  " stop if velocity and impulse is not same direction
  if ( l:st.velocity > 0 && a:impulse < 0 )
    \ || ( l:st.velocity < 0 && a:impulse > 0 )
    let s:comfortable_motion_state.impulse -= l:st.velocity * 4 / 5 "stop smoothly
  else
    let s:comfortable_motion_state.impulse = a:impulse - l:st.velocity
  endif
endfunction

function! comfortable_motion#flick(impulse, air_drag)
  call comfortable_motion#flick_impl( a:impulse, g:comfortable_motion_air_drag )
endfunction

function! comfortable_motion#flickDist(dist)
  let l:friction = g:comfortable_motion_friction
  let l:dt = g:comfortable_motion_interval / 1000.0
  let l:fdt = l:friction * l:dt
  let l:fddt = l:fdt * l:dt
  let l:dist_sign = a:dist == 0 ? 0 : a:dist / abs(a:dist)

  let l:impulse = l:fdt * ( sqrt( 2.0 * abs(a:dist) / l:fddt + 1.0/4.0 ) - 1.0/2.0 )

  call comfortable_motion#flick_impl( l:impulse * l:dist_sign, 0 )
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
