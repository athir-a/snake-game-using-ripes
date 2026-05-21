# --- ADDRESSES FROM YOUR RIPES EXPORT ---
.equ LED_BASE,    0xf0000000   # LED_MATRIX_0_BASE
.equ D_PAD_UP,    0xf0000dac   # D_PAD_0_UP
.equ D_PAD_DOWN,  0xf0000db0   # D_PAD_0_DOWN
.equ D_PAD_LEFT,  0xf0000db4   # D_PAD_0_LEFT
.equ D_PAD_RIGHT, 0xf0000db8   # D_PAD_0_RIGHT

.equ MAX_LEN,     128         # Maximum number of body segments

.data

snake_x: .zero 512    # 512 bytes of zeros = 128 words for X coordinates
snake_y: .zero 512    # 512 bytes of zeros = 128 words for Y coordinates
length:  .word 1      # Current snake length

.text
.globl _start

_start:
    li   s10, LED_BASE   # s10 = base address of LED screen (never changes)

    # --- Initial snake state ---
    li   s2, 17          # Head X = 17 (horizontal center of 35-wide screen)
    li   s3, 12          # Head Y = 12 (vertical center of 25-tall play area)
    li   s4, 3           # Direction = RIGHT
    li   s7, 1           # Length = 1 segment (just the head)

    # --- Write initial head position into body arrays ---
    # snake_x[0] = 17
    la   t0, snake_x     # t0 = address of snake_x array
    sw   s2, 0(t0)       # snake_x[0] = head X
    la   t0, snake_y     # t0 = address of snake_y array
    sw   s3, 0(t0)       # snake_y[0] = head Y

    # --- Write initial length to memory ---
    la   t0, length
    sw   s7, 0(t0)       # length = 1

    # --- Initial apple position ---
    li   s5, 5           # Apple X
    li   s6, 5           # Apple Y

    # --- Draw the initial apple so it's visible from frame 1 ---
    mv   a0, s5
    mv   a1, s6
    li   a2, 0xFF0000
    jal  draw_pixel

game_loop:
    li   s8, 0           # Reset ate_flag to 0 at the start of every frame

    la   t0, snake_x            # t0 = start of snake_x array
    slli t1, s7, 2              # t1 = length * 4  (byte offset to one-past-end)
    add  t0, t0, t1             # t0 = address of snake_x[length]
    lw   a0, -4(t0)             # a0 = snake_x[length-1] = tail X

    la   t0, snake_y
    slli t1, s7, 2
    add  t0, t0, t1
    lw   a1, -4(t0)             # a1 = snake_y[length-1] = tail Y

    li   a2, 0x000000           # Black = erase
    jal  draw_pixel             # Erase old tail pixel

    li   t0, D_PAD_UP
    lw   t1, 0(t0)
    bnez t1, set_up

    li   t0, D_PAD_DOWN
    lw   t1, 0(t0)
    bnez t1, set_down

    li   t0, D_PAD_LEFT
    lw   t1, 0(t0)
    bnez t1, set_left

    li   t0, D_PAD_RIGHT
    lw   t1, 0(t0)
    bnez t1, set_right

    j    apply_movement

set_up:    li s4, 0  
 j apply_movement
set_down:  li s4, 1 
  j apply_movement
set_left:  li s4, 2  
 j apply_movement
set_right: li s4, 3

apply_movement:
    li   t0, 0
    beq  s4, t0, go_up
    li   t0, 1
    beq  s4, t0, go_down
    li   t0, 2
    beq  s4, t0, go_left
    j    go_right              # direction must be 3

go_up:    addi s3, s3, -1 
  j check_bounds
go_down:  addi s3, s3, 1  
  j check_bounds
go_left:  addi s2, s2, -1 
  j check_bounds
go_right: addi s2, s2, 1

check_bounds:
    li   t0, 34
    bgt  s2, t0, reset         # X > 34 → hit right wall
    blt  s2, zero, reset       # X < 0  → hit left wall
    li   t0, 24
    bgt  s3, t0, reset         # Y > 24 → hit bottom wall
    blt  s3, zero, reset       # Y < 0  → hit top wall

    bne  s2, s5, no_eat        # Head X != Apple X → not eating
    bne  s3, s6, no_eat        # Head Y != Apple Y → not eating

    # Snake ate the apple!
    li   s8, 1                 # Set ate_flag = 1

    # Increase length (but cap at MAX_LEN)
    li   t0, MAX_LEN
    bge  s7, t0, skip_grow     # Don't grow beyond max
    addi s7, s7, 1             # length++
    la   t0, length
    sw   s7, 0(t0)             # Update length in memory
skip_grow:

    # Move apple to new "random" position
    addi s5, s5, 7
    andi s5, s5, 31            # Keep X in 0–31
    addi s6, s6, 5
    andi s6, s6, 15            # Keep Y in 0–15

no_eat:

    addi t2, s7, -1            # t2 = i = length - 1  (start index)
    la   t3, snake_x           # t3 = base of snake_x
    la   t4, snake_y           # t4 = base of snake_y

shift_loop:
    blez t2, shift_done        # If i <= 0, done shifting

    slli t0, t2, 2             # t0 = i * 4  (byte offset for index i)
    addi t1, t0, -4            # t1 = (i-1) * 4  (byte offset for index i-1)

    add  t5, t3, t1            # t5 = &snake_x[i-1]
    lw   t6, 0(t5)             # t6 = snake_x[i-1]
    add  t5, t3, t0            # t5 = &snake_x[i]
    sw   t6, 0(t5)             # snake_x[i] = snake_x[i-1]

    add  t5, t4, t1            # t5 = &snake_y[i-1]
    lw   t6, 0(t5)             # t6 = snake_y[i-1]
    add  t5, t4, t0            # t5 = &snake_y[i]
    sw   t6, 0(t5)             # snake_y[i] = snake_y[i-1]

    addi t2, t2, -1            # i--
    j    shift_loop

shift_done:
    # Write new head position into body[0]
    la   t0, snake_x
    sw   s2, 0(t0)             # snake_x[0] = new head X
    la   t0, snake_y
    sw   s3, 0(t0)             # snake_y[0] = new head Y

    li   t2, 0                 # t2 = loop index i = 0
    la   t3, snake_x
    la   t4, snake_y

draw_body_loop:
    bge  t2, s7, draw_body_done   # If i >= length, done

    slli t0, t2, 2             # t0 = i * 4
    add  t5, t3, t0
    lw   a0, 0(t5)             # a0 = snake_x[i]
    add  t5, t4, t0
    lw   a1, 0(t5)             # a1 = snake_y[i]

    # Choose color: head = bright green, body = dark green
    li   a2, 0x007700          # Default: dark green (body)
    bnez t2, not_head          # If i != 0, use body color
    li   a2, 0x00FF00          # If i == 0, use bright green (head)
not_head:
    jal  draw_pixel            # Draw this segment

    addi t2, t2, 1             # i++
    j    draw_body_loop

draw_body_done:
    mv   a0, s5
    mv   a1, s6
    li   a2, 0xFF0000          # Red
    jal  draw_pixel

    li   t0, 15000
delay:
    addi t0, t0, -1
    bnez t0, delay

    j    game_loop             # Back to top of main loop

draw_pixel:
    slli t4, a1, 7    # t4 = Y * 128
    slli t5, a1, 3    # t5 = Y * 8
    add  t4, t4, t5   # t4 = Y * 136
    slli t5, a1, 2    # t5 = Y * 4
    add  t4, t4, t5   # t4 = Y * 140
    slli t5, a0, 2    # t5 = X * 4
    add  t4, t4, t5   # t4 = Y*140 + X*4  (total offset)
    add  t5, t4, s10  # t5 = LED_BASE + offset  (pixel address)
    sw   a2, 0(t5)    # Write color to that address
    ret               # Return to caller

reset:
    # Erase the entire snake body before resetting
    li   t2, 0
    la   t3, snake_x
    la   t4, snake_y
erase_loop:
    bge  t2, s7, erase_done
    slli t0, t2, 2
    add  t5, t3, t0
    lw   a0, 0(t5)
    add  t5, t4, t0
    lw   a1, 0(t5)
    li   a2, 0x000000
    jal  draw_pixel
    addi t2, t2, 1
    j    erase_loop
erase_done:

    # Reset all state back to starting values
    li   s2, 17
    li   s3, 12
    li   s4, 3
    li   s7, 1

    # Write reset state to memory
    la   t0, snake_x
    sw   s2, 0(t0)
    la   t0, snake_y
    sw   s3, 0(t0)
    la   t0, length
    sw   s7, 0(t0)

    j    game_loop
