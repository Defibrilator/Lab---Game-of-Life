
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


############################################    MAIN    ###############################################
main:
	addi sp, zero, 0x2000						#init stack pointer to 0x2000 going downwards

	GoL:
		call reset_game
		call get_input
		add t0, zero, v0						#t0 = edgecapture
		add t1, zero, zero						#t1: done = false
	not_done:
		add a0, zero, t0
		call select_action
		call update_state
		call update_gsa
		call mask
		call draw_gsa
		call wait
		call decrement_step
		add t1, zero, v0						#t1 = done
		call get_input
		add t0, zero, v0						#t0 = edgecapture
		beq t0, zero, not_done					#while !done, loop not_done
		beq zero, zero, GoL						#while true, loop GoL

	ret

#######################################################################################################
	
	#TESTED
	; BEGIN:clear_leds
	clear_leds:
		stw zero, LEDS(zero)
		stw zero, LEDS+4(zero)
		stw zero, LEDS+8(zero)
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
		ret								#return
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
		ret								#return
	; END:wait	

	#TESTED
	; BEGIN:get_gsa
	get_gsa:
		ldw t0, GSA_ID(zero)					#load GSA_ID in t0
		slli t1, a0, 2							#t1 = a0 * 4
		bne t0, zero, gsa1_get					#if the current gsa is 1 go to gsa1_get
		ldw v0, GSA0(t1)						#load GSA0(t1) in v0
		br end_get_gsa							#return
	gsa1_get:
		ldw v0, GSA1(t1)						#load GSA1(t1) in v0
	end_get_gsa:
		ret								#return
	; END:get_gsa

	#TESTED
	; BEGIN:set_gsa
	set_gsa:
		ldw t0, GSA_ID(zero)					#load GSA_ID in t0
		slli t1, a1, 2							#t1 = a0 * 4
		bne t0, zero, gsa1_set					#if the current gsa is the 0 go to gsa1_set
		stw a0, GSA0(t1)						#store a0 (the line) in correct GSA0 element
		br end_set_gsa							#return
	gsa1_set:
		stw a0, GSA1(t1)						#store t1 (the line) in correct GSA1 element
	end_set_gsa:
		ret								#return
	; END:set_gsa

	#TESTED
	; BEGIN:draw_gsa
	draw_gsa:
		addi sp, sp, -8							#decrement stack pointer
		stw ra, 0(sp)							#add return address to the stack
		stw s0, 4(sp)							#backup s0
		
		call clear_leds

		add t6, zero, zero						#t6 = 0 the i loop counter
		add t7, zero, zero						#t7 = 0 the j loop counter
	for_i_draw_gsa:
		add a0, t6, zero						#a0 = i
		call get_gsa							#get_gsa(i)
		add s0, v0, zero						#s0 = get_gsa(i)
	for_j_draw_gsa:
		addi t0, zero, 1						#init mask to t0
		sll t0, t0, t7							#t0 << j
		and t1, s0, t0							#t1 = pixel(x, y)
		beq t1, zero, if_draw_gsa				#if pixel(x, y) = 0, skip
		add a0, t7, zero						#a0 = j = x
		add a1, t6, zero						#a1 = i = y
		call set_pixel							#set_pixel(j, i)
	if_draw_gsa:
		addi t7, t7, 1							#j = j + 1
		addi t0, zero, N_GSA_COLUMNS			#t0 = 12
		addi t1, zero, N_GSA_LINES				#t1 = 8
		blt t7, t0, for_j_draw_gsa				#loop if j < 12
		add t7, zero, zero						#j = 0
		addi t6, t6, 1							#i = i + 1
		blt t6, t1, for_i_draw_gsa				#loop if i < 8

		ldw s0, 4(sp)							#copy s0 back
		ldw ra, 0(sp)							#copy return address from stack to ra
		addi sp, sp, 8							#increment stack pointer
		ret
	; END:draw_gsa

    ; BEGIN:random_gsa
	random_gsa:
		addi sp, sp, -4							#decrement stack pointer
		stw ra, 0(sp)							#add return address to the stack

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
		call set_gsa							#set current finished line
		addi t3, zero, 0						#rest i counter
		addi t2, t2, 1							#j = j + 1
	if_random_gsa:
		blt t2, t6, for_i_lines					#jump back if j is less than cols
		
		ldw ra, 0(sp)							#copy return address from stack to ra
		addi sp, sp, 4							#increment stack pointer
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

		#TESTED
    ; BEGIN:pause_game
	pause_game:
		ldw t0, PAUSE(zero)					#load the pause flag
		xori t0, t0, 1						#flip it
		stw t0, PAUSE(zero)					#store it back
		ret
	; END:pause_game
		
		#TESTED
    ; BEGIN:change_steps
	change_steps:
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
	; END:change_steps

    ; BEGIN:increment_seed
	increment_seed:
		addi sp, sp ,-4
		stw ra, 0(sp)

		ldw t0, SEED(zero)						#load seed in t0
		addi t0, t0, 1							#increment by 1
		addi t1, zero, N_SEEDS
		bge t0, t1, rand_set					#if over N goto rand_set
		stw t0, SEED(zero)						#store it in SEED

		slli t0, t0, 2							#t0 * 4 for addressing
		ldw t2, SEEDS(t0)						#t2 has the current seed
		
		addi t1, zero, 0						#i=0
		addi t3, zero, N_GSA_LINES				#max lines
	incr_loop:
		beq t1, t3, increment_end				#goto end if i = N_GSA_LINES
		ldw t4, 0(t2)							#t4 = corresponding line
		add a0, zero, t4						#set arg0 to t4
		add a1, zero, t1						#set arg1 to i

		addi sp, sp, -8
		stw t0, 0(sp)
		stw t1, 4(sp)
		call set_gsa							#set the new line
		ldw t1, 4(sp)
		ldw t0, 0(sp)
		addi sp, sp, 8

		addi t2, t2, 4							#increment t2 by 4
		addi t1, t1, 1							#i=i+1
		jmpi incr_loop							#loop back

	rand_set:
		call random_gsa

	increment_end:
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
	; END:increment_seed
		
#TESTED
	; BEGIN:update_state
	update_state:
		addi sp, sp, -4
		stw ra, 0(sp)

		ldw t0, CURR_STATE(zero)				#t0 = CURR_STATE
		addi t1, zero, INIT						#t1 = 0
		addi t2, zero, RAND						#t2 = 1
		addi t3, zero, RUN						#t3 = 2
		addi t6, zero, 1						#t6 = 1
		slli t6, t6, 1							#t6 = 0b10
		and t6, t6, a0							#t6 = b1
		beq t0, t1, update_state_init			#update from init
		beq t0, t2, update_state_rand			#update from rand
		beq t0, t3, update_state_run			#update from run

		#INIT
	update_state_init:
		ldw t4, SEED(zero) 						#t4 = SEED
		addi t5, zero, N_SEEDS					#t5 = N_SEEDS
		beq t4, t5, us_init_to_rand				#if b0 = N -> change state to rand
		bne t6, zero, us_init_to_run			#else if b1 != 1 -> change state to run
		br end_update_state						#else ret
	us_init_to_run:
		stw t3, CURR_STATE(zero)				#CURR_STATE = RUN
		stw t2, PAUSE(zero)						#Game Paused = 1 (running)
		br end_update_state						#ret
	us_init_to_rand:
		stw t2, CURR_STATE(zero)				#CURR_STATE = RAND
		br end_update_state						#ret

		#RAND
	update_state_rand:
		andi t4, a0, 1							#t4 = b0
		bne t4, zero, end_update_state			#if b0 = 1 -> do nothing		 
		bne t6, zero, us_rand_to_run			#if b1 != 0 -> change to run
		br end_update_state						#else stay on rand
	us_rand_to_run:
		stw t3, CURR_STATE(zero)				#CURR_STATE = RUN
		stw t2, PAUSE(zero)						#Game Paused = 1 (running)
		br end_update_state						#ret

		#RUN
	update_state_run:
		addi t6, zero, 1						#t6 = 1
		slli t6, t6, 3							#t6 = 0b1000
		and t6, t6, a0							#t6 = b3
		bne t6, zero, us_run_to_init			#if b3 != 0 -> change to init
		ldw t0, CURR_STEP(zero)					#t0 = CURR_STEP
		addi t4, zero, MAX_STEP					#t4 = MAX_STEP
		bge t0, t4, us_run_to_init				#else if CURR_STEP >= MAX_STEP -> change to init
		br end_update_state						#else return
	us_run_to_init:
		stw t1, CURR_STATE(zero)				#else CURR_STATE = INIT
		call reset_game							#reset game
		
	end_update_state:
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
	; END:update_state

    ; BEGIN:select_action
	select_action:
		addi sp, sp, -8							#decrement stack pointer
		stw ra, 0(sp)							#backup ra in stack
		stw s1, 4(sp)							#backup s1

		ldw t0, CURR_STATE(zero)				#t0 = CURR_STATE
		addi t2, zero, RAND						#t2 = 1
		addi t3, zero, RUN						#t3 = 2
		and t4, t2, a0							#t4 = b0
		slli t5, t2, 1							#t5 = 0b00010
		and t5, t5, a0							#t5 = b1
		slli t6, t2, 2							#t6 = 0b00100
		and t6, t6, a0							#t6 = b2
		slli t7, t2, 3							#t7 = 0b01000
		and t7, t7, a0							#t7 = b3
		slli t1, t2, 4							#t1 = 0b10000
		and t1, t1, a0							#t1 = b4
		beq t0, zero, select_init				#update from init
		beq t0, t2, select_rand					#update from rand
		beq t0, t3, select_run					#update from run

	select_init:
		bne t4, zero, sa_increment_seed			#if b0 = 1 -> increment seed
		bne t5, zero, sa_start_game				#else if b1 = 1 -> start game
		or s1, t6, t7							#s1 = b2 or b3
		or s1, s1, t1							#s1 = s1 or b4
		bne s1, zero, sa_change_step			#else if b2 or b3 or b4 = 1 -> change_step
		br end_select_action					#else do nothing

	select_rand:
		bne t4, zero, sa_pause_game				#if b0 = 1 -> increment seed
		bne t5, zero, sa_start_game				#else if b1 = 1 -> start game
		or s1, t6, t7							#s1 = b2 or b3
		or s1, s1, t1							#s1 = s1 or b4
		bne s1, zero, sa_change_step			#else if b2 or b3 or b4 = 1 -> change_step
		br end_select_action					#else do nothing

	select_run:
		bne t4, zero, sa_pause_game				#if b0 = 1 -> pause game
		bne t5, zero, sa_inc_speed				#else if b1 = 1 -> increase speed
		bne t6, zero, sa_dec_speed				#if b2 = 1 -> decrease speed
		bne t7, zero, sa_reset_game				#else if b3 = 1 -> reset game
		bne t1, zero, sa_random_gsa				#if b4 = 1 -> random gsa		
		br end_select_action

	sa_increment_seed:
		call increment_seed						#increment seed
		br end_select_action					#return

	sa_start_game:
		call update_state						#change state
		br end_select_action					#return
		
	sa_change_step:
		cmpne a0, t1, zero						#a0 = b4
		cmpne a1, t7, zero						#a1 = b3
		cmpne a2, t6, zero						#a1 = b2
		call change_steps						#change_step
		br end_select_action					#return

	sa_random_gsa:
		call random_gsa							#random gsa
		br end_select_action					#return

	sa_pause_game:
		call pause_game							#pause_game
		br end_select_action					#return

	sa_inc_speed:
		add a0, zero, zero						#a0 = 0
		call change_speed						#increment speed
		br end_select_action					#return

	sa_dec_speed:
		addi a0, zero, 1						#a0 = 1
		call change_speed						#decrement speed
		br end_select_action					#return

	sa_reset_game:
		call reset_game							#reset_game


	end_select_action:
		ldw s1, 4(sp)							#copy s1 back
		ldw ra, 0(sp)							#copy return address from stack to ra
		addi sp, sp, 8							#increment stack pointer
		ret
	; END:select_action
    ; BEGIN:cell_fate
	cell_fate:
		addi t0, zero, 2
		addi t1, zero, 3
		addi t2, zero, 4
		bne a1, zero, cf_is_alive					#if a1 != 0 -> is_alive else is_dead
	
	cf_is_dead:
		beq a0, t1, cf_change_state					#if dead and 3 neighbours -> change state
		add v0, zero, zero							#else v0 = 0
		br end_cell_fate

	cf_is_alive:
		blt a0, t0, cf_change_state					#if a0 < 2 -> change_state
		bge  a0, t2, cf_change_state				#else if a0 > 3 -> change_state
		addi v0, zero, 1							#else v0 = 1
		br end_cell_fate							#return

	cf_change_state:
		xori v0, a1, 1								#v0 = !a1

	end_cell_fate:
		ret
	; END:cell_fate

    ; BEGIN:find_neighbours
	find_neighbours:
		#a0 = x coordinate
		#a1 = y coordinate
		#v0 = nb of neighbours
		#v1 = state of the cell in question
		addi sp, sp, -12
		stw ra, 0(sp)							#store x in stack
		stw a1, 4(sp)							#store y in stack

		addi t1, zero, N_GSA_COLUMNS
		addi t0, a0, -1							#t0 = x-1

		bge t0, zero, start_nei						
	minus_rol:
		addi t0, t1, -1
		jmpi start_nei	
	start_nei:
		stw t0, 8(sp)
		addi a1, a1, -1							#start iteration at y-1
		addi t4, zero, 0						#j = 0
		addi t5, zero, 0						#sum = 0		
		addi t6, zero, 3						#bound for both loops
		jmpi neighbour_loop
	pre_neigh:
		ldw t0, 8(sp)
		addi t4, t4, 1							#j+=1
		addi a1, a1, 1							#line += 1
		bge t4, t6, end_neighbours					#end loop if j >= 3
	neighbour_loop:		
		add a2, zero, a1						# a2 = y
		addi a3, zero, 8						# mod 8
		call mod							#apply modulo
		add a0, zero, v0						#y coordinate for line
		call get_gsa
		ldw a3, 8(sp)							#a3 is now the rotation to get center at index 1
		add a2, zero, v0						#the line in question
		call custom_rol
		
		addi t7, zero, 0						#i = 0
		
		ldw t1, 4(sp)
		bne a1, t1, non_cell_line					#cell line or not

	cell_line:
		andi t2, v0, 5							#state of side neighbours
		andi t3, t2, 1							#last cell
		add t5, t5, t3							#add neighbour to t5 which is the sum of neighbours
		srli t2, t2, 2							#shift by 2
		andi t3, t2, 1							#last cell
		add t5, t5, t3							#add left neighbour
		andi v1, v0, 2							#mask for the cell state	
		jmpi pre_neigh
		
	non_cell_line:
		andi t3, v0, 1							#last cell
		add t5, t5, t3							#add neighbour to t5 which is the sum of neighbours
		srli v0, v0, 1							#shift line by one
		addi t7, t7, 1							#i += 1
		bge t7, t6, pre_neigh						#loop it when i!=3
		jmpi non_cell_line
		
	end_neighbours:
		ldw ra, 0(sp)
		addi sp, sp, 12
		add v0, zero, t5						#v0 is total sum t5
		srli v1, v1, 1
		ret
	; END:find_neighbours

#TODO
    ; BEGIN:update_gsa
	update_gsa:
		addi sp, sp, -8
		stw s0, 0(sp)
		stw ra, 4(sp)

		ldw t0, PAUSE(zero)						#t0 = GAME_PAUSED
		beq t0, zero, end_update_gsa			#if (game is paused) -> do nothing
		ldw t1, GSA_ID(zero)					#t1 = GSA_ID
		add t2, zero, zero 						#t2 = i = 0 (y)
		add t3, zero, zero						#t3 = j = 0 (x)
		addi t5, zero, N_GSA_COLUMNS			#t5 = 12
		addi t6, zero, N_GSA_LINES				#t6 = 8
		add s0, zero, zero						#s0 = 0 (the line)

	ug_for:
		add a0, zero, t3						#a0 = x
		add a1, zero, t2						#a1 = y

		addi sp, sp, -28
		stw t0, 0(sp)
		stw t1, 4(sp)
		stw t2, 8(sp)
		stw t3, 12(sp)
		stw t4, 16(sp)
		stw t5, 20(sp)
		stw t6, 24(sp)

		call find_neighbours					#find_neighbours(x, y)
		add a0, zero, v0						#a0 = # of living neighbours
		add a1, zero, v1						#a1 = state of cell
		call cell_fate							#cell_fate(x, y)
		ldw t0, 0(sp)
		ldw t1, 4(sp)
		ldw t2, 8(sp)
		ldw t3, 12(sp)
		ldw t4, 16(sp)
		ldw t5, 20(sp)
		ldw t6, 24(sp)
		addi sp, sp, 28

		beq zero, v0, ug_skip_activate			#if v0 = 0 skip activation
		addi t4, zero, 1						#t4 = 1
		sll t4, t4, t3							#t4 = t4 << x
		or s0, s0, t4							#add bit to the line
	ug_skip_activate:
		addi t3, t3, 1							#j = j + 1
		blt t3, t5, ug_for						#loop if j < 12
		ldw t1, GSA_ID(zero)					#t1 = GSA_ID
		xori t1, t1, 1							#flip t1
		stw t1, GSA_ID(zero)					#store GSA_ID
		add a0, zero, s0						#a0 = the line
		add a1, zero, t2						#a1 = y
		call set_gsa							#set_gsa(line, y)
		ldw t1, GSA_ID(zero)					#t1 = GSA_ID
		xori t1, t1, 1							#flip t1
		stw t1, GSA_ID(zero)					#store GSA_ID
		addi t2, t2, 1							#i = i + 1
		add t3, zero, zero						#j = 0
		add s0, zero, zero						#s0 = 0
		blt t2, t6, ug_for						#loop if i < 8

	ug_finish_update:
		ldw t1, GSA_ID(zero)					#t1 = GSA_ID
		xori t1, t1, 1							#flip t1
		stw t1, GSA_ID(zero)					#store GSA_ID

	end_update_gsa:
		ldw s0, 0(sp)
		ldw ra, 4(sp)
		addi sp, sp, 8
		ret
	; END:update_gsa

    ; BEGIN:mask
	mask:
		addi sp, sp, -4
		stw ra, 0(sp)

		ldw t0, SEED(zero)						#load current seed
		slli t0, t0, 2							#t0 * 4 for addressing
		addi t1, zero, 0						#i = 0
		addi t2, zero, N_GSA_LINES				#bound by 
		ldw t3, MASKS(t0)						#t3 has the current mask

	seed_mask:
		add a0, zero, t1						
		addi sp, sp, -8
		stw t0, 0(sp)
		stw t1, 4(sp)
		call get_gsa							#get line i
		ldw t1, 4(sp)
		ldw t0, 0(sp)
		addi sp, sp, 8	

		slli t1, t1, 2							#t1 * 4 for addressing

		ldw t4, 0(t3)							#t4 has the current maks line
		srli t1, t1, 2							#go back to i for t1

		and a0, v0, t4							#apply the mask
		add a1, zero, t1						#set y coordinate
		addi sp, sp, -8
		stw t0, 0(sp)
		stw t1, 4(sp)
		call set_gsa							#set the newly masked line
		ldw t1, 4(sp)
		ldw t0, 0(sp)
		addi sp, sp, 8		

		addi t3, t3, 4							#increment t3 by 4
		addi t1, t1, 1							#i+=1 and loop
		blt t1, t2, seed_mask					#loop if i < N_GSA_LINES
	
	end_mask:
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
		

	; END:mask

    ; BEGIN:get_input
	get_input:
		ldw t0, BUTTONS+4(zero)
		addi t2, zero, 1						#t2 = 1

		and t4, t2, t0							#t4 = b0
		bne t4, zero, end_get_input				#if b0 != 0 -> return

		slli t4, t2, 1							#t4 = 0b00010
		and t4, t4, t0							#t4 = b1
		bne t4, zero, end_get_input				#if b1 != 0 -> return

		slli t4, t2, 2							#t4 = 0b00100
		and t4, t4, t0							#t4 = b2
		bne t4, zero, end_get_input				#if b2 != 0 -> return

		slli t4, t2, 3							#t4 = 0b01000
		and t4, t4, t0							#t4 = b3
		bne t4, zero, end_get_input				#if b3 != 0 -> return

		slli t4, t2, 4							#t4 = 0b10000
		and t4, t4, t0							#t4 = b4

	end_get_input:
		add v0, zero, t4						#v0 = t4
		stw zero, BUTTONS+4(zero)
		ret
	; END:get_input

#TODO
    ; BEGIN:decrement_step
	decrement_step: 
		ldw t0, PAUSE(zero)						#t0 = PAUSE
		ldw t2, CURR_STEP(zero)					#t2 = CURR_STEP
		beq t0, zero, ds_ret_zero				#else if pause == 0 -> display and return 0
		ldw t1, CURR_STATE(zero)				#t1 = CURR_STATE
		cmpeqi t1, t1, RUN						#t1 = curr_state == run
		beq t1, zero, ds_ret_zero				#if t1 = false -> display and return 0
		beq t2, zero, ds_ret_one				#if curr_step == 0 -> return 1
		addi t2, t2, -1							#decrement curr_step
		stw t2, CURR_STEP(zero)					#store curr_step
		br ds_ret_zero							#display and return 0
		
	ds_ret_one:
		addi v0, zero, 1						#v0 = 1
		br end_decrement_step					#return
		
	ds_ret_zero:
		add v0, zero, zero						#v0 = 0

	display_segs:
		addi t3, zero, 0xF						#t3 = 0xF

		and t4, t2, t3							#t4 = seven_segs(3)
		srli t5, t2, 4							#t5 = curr_step >> 4
		and t5, t5, t3							#t5 = seven_segs(2)
		srli t6, t2, 8							#curr_step shift right
		and t6, t6, t3							#t6 = seven_segs(1)
		srli t7, t2, 12							#curr_step shift right
		and t7, t7, t3							#t7 = seven_segs(0)
		
		slli t4, t4, 2
		ldw t4, font_data(t4)					#t4 = display(t4)
		slli t5, t5, 2
		ldw t5, font_data(t5)					#t5 = display(t5)
		slli t6, t6, 2
		ldw t6, font_data(t6)					#t6 = display(t6)
		slli t7, t7, 2
		ldw t7, font_data(t7)					#t7 = display(t7)

		stw t4, SEVEN_SEGS+12(zero)
		stw t5, SEVEN_SEGS+8(zero)
		stw t6, SEVEN_SEGS+4(zero)
		stw t7, SEVEN_SEGS(zero)

	end_decrement_step:
		ret
	; END:decrement_step

#TODO
    ; BEGIN:reset_game
	reset_game:
		addi sp, sp, -4
		stw ra, 0(sp)

		addi t0, zero, 1						#t0 = 1
		stw t0, CURR_STEP(zero)					#CURR_STEP = 1

		ldw t1, font_data+4(zero)				#t1 = display(1)
		ldw t2, font_data(zero)					#t2 = display(0)
		add a1, zero, zero						#a1 = i = 0

		stw t1, SEVEN_SEGS+12(zero)
		stw t2, SEVEN_SEGS+8(zero)
		stw t2, SEVEN_SEGS+4(zero)
		stw t2, SEVEN_SEGS(zero)				#display 0001

		stw zero, SEED(zero)					#SEED = 0
		stw zero, GSA_ID(zero)					#GSA_ID = 0
		stw zero, PAUSE(zero)					#Game is paused	
		stw t0, SPEED(zero)						#SPEED = 1

		#Game state 0 is initialized to the seed 0
		ldw a0, seed0(zero)
		call set_gsa
		ldw a0, seed0+4(zero)
		addi a1, a1, 1							#a1 = a1 + 1
		call set_gsa
		ldw a0, seed0+8(zero)
		addi a1, a1, 1							#a1 = a1 + 1
		call set_gsa
		ldw a0, seed0+12(zero)
		addi a1, a1, 1							#a1 = a1 + 1
		call set_gsa
		ldw a0, seed0+16(zero)
		addi a1, a1, 1							#a1 = a1 + 1
		call set_gsa
		ldw a0, seed0+20(zero)
		addi a1, a1, 1							#a1 = a1 + 1
		call set_gsa
		ldw a0, seed0+24(zero)
		addi a1, a1, 1							#a1 = a1 + 1
		call set_gsa
		ldw a0, seed0+28(zero)
		addi a1, a1, 1							#a1 = a1 + 1
		call set_gsa
		
		call mask
		call draw_gsa

	end_reset_game:
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
	; END:reset_game

	;BEGIN:helper
	.equ MAX_STEP, 0x1000

	mod:
		addi sp, sp, -4
		stw ra, 0(sp)
	mod_loop:
		blt a2, zero, negative			#procedure for negatives
		blt a2, a3, end_mod				#end condition
		sub a2, a2, a3					#a=a-mod                      mod is a3
		jmpi mod_loop					#loop it
	negative:
		bge a2, zero, end_mod			#a>=0  -> end
		add a2, a2, a3					#a=a+mod
		jmpi negative
	end_mod:
		add v0, zero, a2				#return a0 mod a1
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret

	custom_rol:
		#a2 the line
		#a3 the shift
		beq a3, zero, noroll
		addi sp, sp, -4
		stw ra, 0(sp)
		add t0, zero, a2
		add t1, zero, a3
	lil_loop:
		addi t2, zero, 1
		ror t0, t0, t2
		slli t2, t2, 31
		and t2, t2, t0
		srli t2, t2, 20
		add t0, t0, t2
		andi v0, t0, 0xFFF
		addi t1, t1, -1
		bne t1, zero, lil_loop
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
	noroll:
		add v0, zero, a2
		ret
	;END:helper

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
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF

mask1:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x1FF
	.word 0x1FF
	.word 0x1FF

mask2:
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF

mask3:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000

mask4:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000

MASKS:
    .word mask0
    .word mask1
    .word mask2
    .word mask3
    .word mask4
