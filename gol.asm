    ;; game state memory location
    .equ CURR_STATE, 0x1000        ; current game state
    .equ GSA_ID, 0x1004            ; gsa currently in use for drawing
    .equ PAUSE, 0x1008             ; is the game paused or running
    .equ SPEED, 0x100C             ; game speed
    .equ CURR_STEP,  0x1010        ; game current step
    .equ SEED, 0x1014              ; game seed
    .equ GSA0, 0x1018              ; GSA0 starting address
    .equ GSA1, 0x1038              ; GSA1 starting address
    .equ SEVEN_SEGS, 0x1198        ; 7-segment display addresses
    .equ CUSTOM_VAR_START, 0x1200  ; Free range of addresses for custom variable definition
    .equ CUSTOM_VAR_END, 0x1300
    .equ LEDS, 0x2000              ; LED address
    .equ RANDOM_NUM, 0x2010        ; Random number generator address
    .equ BUTTONS, 0x2030           ; Buttons addresses

    ;; states
    .equ INIT, 0
    .equ RAND, 1
    .equ RUN, 2

    ;; constants
    .equ N_SEEDS, 4
    .equ N_GSA_LINES, 8
    .equ N_GSA_COLUMNS, 12
    .equ MAX_SPEED, 10
    .equ MIN_SPEED, 1
    .equ PAUSED, 0x00
    .equ RUNNING, 0x01
	.equ MAX_STEP, 0x1000

main: 
	
	
	#TESTED
	; BEGIN:clear_leds
	clear_leds:
		addi t3, zero, 4						#init t3 to 4
		addi t4, zero, 8						#init t4 to 8
		stw zero, LEDS(zero)
		stw zero, LEDS(t3)
		stw zero, LEDS(t4)
		ret
	; END:clear_leds

	#TESTED
    ; BEGIN:set_pixel
	set_pixel:
		add t0, a0, zero						#t0 = x
		andi t1, a0, 3							#t1 = x mod 4
		addi t2, zero, 1						#init t2 to mask
		sll t2, t2, a1							#shift mask t2 by y
		addi t3, zero, 1						#init t3 to 1	
		ldw t5, LEDS(t0)						#load leds(x) in t5
		beq t1, zero, cont_sp					#if t1 = 0, skip loop
	loop_sp:
		slli t2, t2, N_GSA_LINES				#shift mask by 8
		sub t1, t1, t3							#t1 = t1 - 1
		bne t1, zero, loop_sp					#loop if t1 != 0
	cont_sp:
		or t5, t5, t2							#set LED(x, y) to 1
		stw t5, LEDS(t0)						#store t5 in leds(x/4)
		ret										#return
	; END:set_pixel

    ; BEGIN:wait
	wait:
		addi t0, zero, 1						#t0 = 1
		ldw t1, SPEED(zero)						#t1 = SPEED
		addi t2, zero, 0x800					#t2 = 2^11
		slli t2, t2, 8							#t2 = 2^19
	loop_wait:
		blt t2, t0, end_wait					#end loop if t2 < 1
		sub t2, t2, t1							#t2 = t2 - SPEED
		jmpi loop_wait							#loop
	end_wait:
		ret										#return
	; END:wait	

	#TESTED
	; BEGIN:get_gsa
	get_gsa:
		ldw t0, GSA_ID(zero)					#load GSA_ID in t0
		bne t0, zero, gsa1_get					#if the current gsa is 1 go to gsa1_get
		ldw v0, GSA0(a0)						#load GSA0(a0) in v0
		jmpi end_get_gsa						#return
	gsa1_get:
		ldw v0, GSA1(a0)						#load GSA1(a0) in v0
	end_get_gsa:
		ret										#return
	; END:get_gsa

	; BEGIN:set_gsa
	set_gsa:
		ldw t0, GSA_ID(zero)					#load GSA_ID in t0
		beq t0, zero, gsa1_set					#if the current gsa is the 0 go to gsa1_set
		stw a0, GSA0(a1)						#store a0 (the line) in correct GSA0 element
		jmpi end_get_gsa						#return
	gsa1_set:
		stw a0, GSA1(a1)						#store a0 (the line) in correct GSA1 element
	end_set_gsa:
		ret										#return
	; END:set_gsa

	#TESTED
	; BEGIN:draw_gsa
	draw_gsa:
		add t6, zero, zero						#t6 = 0 the i loop counter (get_gsa)
		add s1, zero, zero						#s1 = 0 the i2 loop counter (set_pixel)
		add t7, zero, zero						#t7 = 0 the j loop counter
	for_i_draw_gsa:
		add a0, t6, zero						#a0 = i
		addi sp, sp, -4							#decrement stack pointer
		stw ra, (sp)							#add return address to the stack
		call get_gsa							#get_gsa(i)
		ldw ra, (sp)							#copy return address from stack to ra
		addi sp, sp, 4							#increment stack pointer
		add s0, v0, zero						#s0 = get_gsa(i)
	for_j_draw_gsa:
		addi t0, zero, 1						#init mask to t0
		sll t0, t0, t7							#t0 << j
		and t1, s0, t0							#t1 = pixel(x, y)
		beq t1, zero, if_draw_gsa				#if pixel(x, y) = 0, skip
		add a0, t7, zero						#a0 = j = x
		add a1, s1, zero						#a1 = i2 = y
		addi sp, sp, -4							#decrement stack pointer
		stw ra, (sp)							#add return address to the stack
		call set_pixel							#set_pixel(j, i2)
		ldw ra, (sp)							#copy return address from stack to ra
		addi sp, sp, 4							#increment stack pointer
	if_draw_gsa:
		addi t7, t7, 1							#j = j + 1
		addi t0, zero, N_GSA_COLUMNS			#t0 = 12
		addi t1, zero, N_GSA_LINES				#t0 = 8
		blt t7, t0, for_j_draw_gsa				#loop if j < 12
		add t7, zero, zero						#j = 0
		addi s1, s1, 1							#i2 = i2 + 1
		addi t6, t6, 4							#i = i + 4
		blt s1, t1, for_i_draw_gsa				#loop if i2 < 8
		ret
	; END:draw_gsa

    ; BEGIN:random_gsa
	random_gsa:
		ldw t0, GSA_ID(zero)					#load gsa id
		addi t2, zero, 0						#j counter for lines
		addi t3, zero, 0						#i counter for columns
		addi t4, zero, 0						#initialize line to 0
		addi t5, zero, N_GSA_COLUMNS
		addi t6, zero, N_GSA_LINES
	for_j_gen_line:
		ldw t1, RANDOM_NUM(zero)				#load random generator in t1
		andi t1, t1, 1							#t4 = rand mod 2 (t1 is the random bit)
		add t4, t4, t1							#t4 added next rand bit
		slli t4, t4, 1							#t4 = shifted line by 1
		addi t3, t3, 1							#i = i + 1
	for_i_lines:
		blt t3, t5, for_j_gen_line				#jump to next line 
		add	a0, zero, t4						#line arg
		add a1, zero, t2						#y coordinate
		addi sp, sp, -4							#decrement stack pointer
		stw ra, (sp)							#add return address to the stack
		call set_gsa							#set current finished line
		ldw ra, (sp)							#copy return address from stack to ra
		addi sp, sp, 4							#increment stack pointer
		addi t3, zero, 0						#rest i counter
		addi t2, t2, 1							#j = j + 1
	if_random_gsa:
		blt t2, t6, for_i_lines					#jump back if j is less than cols
		ret
			
	; END:random_gsa

	#TESTED
    ; BEGIN:change_speed
	change_speed:
		addi t1, zero, 1						#t1 = 1
		addi t2, zero, MAX_SPEED				#t2 = MAX_SPEED
		addi t3, zero, MIN_SPEED				#t3 = MIN_SPEED
		beq a0, zero, speed_up					#a0 0 for increment and 1 for decrement
	speed_down:
		ldw t0, SPEED(zero)						#load current speed
		sub t0, t0, t1							#check for current speed-1
		blt t0, t3, end_ch_speed				#if its under min speed jump to end
		stw t0, SPEED(zero)						#else store it in speed
		br end_ch_speed							#jump to end
	speed_up:
		ldw t0, SPEED(zero)						#same as above but with speed increased
		add t0, t0, t1
		bge t0, t2, end_ch_speed
		stw t0, SPEED(zero)
	end_ch_speed:
		ret
	; END:change_speed

    ; BEGIN:pause_game
	pause_game:
		ldw t0, PAUSE(zero)					#load the pause flag
		xori t0, t0, 1						#flip it
		stw t0, PAUSE(zero)					#store it back
		ret
	; END:pause_game
		
		#TESTED
    ; BEGIN:change_step
	change_step:
		ldw t0, CURR_STEP(zero)				#load current step size
		addi t1, zero, MAX_STEP
		add t0, t0, a0						#add the units
		slli a1, a1, 4						#shift left to get 0x10
		add t0, t0, a1						#add it to the temp step
		slli a2, a2, 8						#get 0x100 or 0x0 same as above
		add t0, t0, a2						#add it to the temp step
		bge t0, t1, reset_step				#check for overflow 
	ch_step:
		stw t0, CURR_STEP(zero)				#store it in mem
		ret
	reset_step:
		addi t2, zero, 1
		stw t2, CURR_STEP(zero)				#store 1 because we have overflow
		ret
	; END:change_step

    ; BEGIN:increment_seed
	increment_seed:
		ldw t0, CURR_STATE(zero)			#load current state
		addi t1, zero, INIT					#t1 = INIT
		addi t2, zero, RAND					#t2 = RAND
	
		beq t0, t1, inc_seed				#if we are in the INIT state
		beq t0, t2, rand_seed				#if we are in the RAND state
	inc_seed:
		ldw t3, SEED(zero)					#t3 = the current game seed
		addi t3, t3, 1						#increment seed by 1
		beq t0, s0, set_new_gsa				
		ret
	rand_seed:
		
		ret
	set_new_gsa:
	; END:increment_seed

	; BEGIN:update_state
	update_state:
		ldw t0, CURR_STATE(zero)				#t0 = CURR_STATE
		addi t1, zero, INIT						#t1 = 0
		addi t2, zero, RAND						#t2 = 1
		addi t3, zero, RUN						#t3 = 2
		addi t6, zero, 1						#t6 = 1
		slli t6, zero, 1						#t6 = 0b10
		and t6, t6, a0							#t6 = b1
		beq t0, t1, update_state_init			#update from init
		beq t0, t2, update_state_rand			#update from rand
		beq t0, t3, update_state_run			#update from run

	#INIT
	update_state_init:
		ldw t4, SEED(zero) 						#t4 = SEED
		ldw t5, N_SEEDS(zero)					#t5 = N_SEEDS
		beq t6, t2, us_init_to_run				#if b1 = 1 -> change state to run
		beq t4, t5, us_init_to_rand				#else if b0 = N -> change state to rand
		jmpi end_update_state					#else ret
	us_init_to_run:
		stw t3, CURR_STATE(zero)				#CURR_STATE = RUN
		stw t2, PAUSE(zero)						#Game Paused = 1 (running)
		jmpi end_update_state					#ret
	us_init_to_rand:
		stw t2, CURR_STATE(zero)				#CURR_STATE = RAND
		addi sp, sp, -4							#decrement stack pointer
		stw ra, (sp)							#add return address to the stack
		call random_gsa							#generate random seed
		ldw ra, (sp)							#copy return address from stack to ra
		addi sp, sp, 4							#increment stack pointer
		jmpi end_update_state					#ret

	#RAND
	update_state_rand:
		beq t6, t2, us_rand_to_run				#if b1 = 1 -> change to run
		jmpi end_update_state					#else stay on rand
	us_rand_to_run:
		stw t3, CURR_STATE(zero)				#CURR_STATE = RUN
		stw t2, PAUSE(zero)						#Game Paused = 1 (running)
		jmpi end_update_state					#ret

	#RUN
	update_state_run:
		addi t6, zero, 1						#t6 = 1
		slli t6, zero, 3						#t6 = 0b1000
		and t6, t6, a0							#t6 = b3
		ldw t0, CURR_STEP(zero)					#t0 = CURR_STEP
		ldw t4, MAX_STEP(zero)					#t4 = MAX_STEP
		blt t0, t4, end_update_state			#if CURR_STEP < MAX_STEP -> do nothing
		bne t6, t2, end_update_state			#or if b1 != 1 -> do nothing
		stw t1, CURR_STATE(zero)				#else CURR_STATE = INIT	
		
	end_update_state:
		ret
	; END:update_state

    ; BEGIN:select_action
	select_action:
		; your implementation code
		ret
	; END:select_action

    ; BEGIN:cell_fate
	cell_fate:
		; your implementation code
		ret
	; END:cell_fate

    ; BEGIN:find_neighbours
	find_neighbours:
		; your implementation code
		ret
	; END:find_neighbours

    ; BEGIN:update_gsa
	update_gsa:
		; your implementation code
		ret
	; END:update_gsa

    ; BEGIN:get_input
	get_input:
		; your implementation code
		ret
	; END:get_input

    ; BEGIN:decrement_step
	decrement_step:
		; your implementation code
		ret
	; END:decrement_step

    ; BEGIN:reset_game
	reset_game:
		; your implementation code
		ret
	; END:reset_game

font_data:
    .word 0xFC ; 0
    .word 0x60 ; 1
    .word 0xDA ; 2
    .word 0xF2 ; 3
    .word 0x66 ; 4
    .word 0xB6 ; 5
    .word 0xBE ; 6
    .word 0xE0 ; 7
    .word 0xFE ; 8
    .word 0xF6 ; 9
    .word 0xEE ; A
    .word 0x3E ; B
    .word 0x9C ; C
    .word 0x7A ; D
    .word 0x9E ; E
    .word 0x8E ; F

seed0:
    .word 0xC00
    .word 0xC00
    .word 0x000
    .word 0x060
    .word 0x0A0
    .word 0x0C6
    .word 0x006
    .word 0x000

seed1:
    .word 0x000
    .word 0x000
    .word 0x05C
    .word 0x040
    .word 0x240
    .word 0x200
    .word 0x20E
    .word 0x000

seed2:
    .word 0x000
    .word 0x010
    .word 0x020
    .word 0x038
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000

seed3:
    .word 0x000
    .word 0x000
    .word 0x090
    .word 0x008
    .word 0x088
    .word 0x078
    .word 0x000
    .word 0x000


    ;; Predefined seeds
SEEDS:
    .word seed0
    .word seed1
    .word seed2
    .word seed3

mask0:
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000

mask1:
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0xE00
    .word 0xE00
    .word 0xE00

mask2:
    .word 0x800
    .word 0x800
    .word 0x800
    .word 0x800
    .word 0x800
    .word 0x800
    .word 0x800
    .word 0x800

mask3:
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0xFFF

mask4:
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0xFFF

MASKS:
    .word mask0
    .word mask1
    .word mask2
    .word mask3
    .word mask4
