pushpc
; VRAM buffer:
; $10C0 = first line -> $D100 in VRAM
; $1100 = second line
; $1780 = last line
; $40 bytes/32 tiles per line.


; Overrides Game Mode 0x0C.
org $00806D : db CM_Main
org $008089 : db CM_Main>>8
org $0080A5 : db CM_Main>>16

pullpc

macro menubeep()
	PHA
	LDA #$0C : STA $012F
	PLA
endmacro

macro set_menu_icon(icon)
	LDA.w #($3000|<icon>)
	ORA $0C
	STA.w SA1RAM.MENU-2, X
endmacro

; jsr ($0000,x) equivalent but program bank != data bank
macro jsr_ptr_table(addr)
	LDA.l <addr>,X
	STA.b $0A
	PEA ?ret-1
	JMP.w ($000A)
?ret:
endmacro

!OPTION_OFFSET = $001E
CM_Main:
	PHB : PHK : PLB

	JSR CM_Local

	PLB
	RTL

 
CM_Local:
	; For all these local $11 indexed subroutines:
	; Enters: AI=8
	; Leave with: AI=8

	LDA $11

	JSL UseImplicitRegIndexedLocalJumpTable

	dw CM_Init
	dw CM_DrawMenu
	dw CM_MenuDown
	dw CM_Active
	dw CM_MenuUp
	dw CM_Return


CM_Init:

	LDA #$01 : STA.w SA1RAM.opened_menu_manually
	; Start with new state when opening the menu.
	JSR cm_clear_stack
	STZ $B1

	REP #$20
	; disable bg1 and bg2
	LDA.b $1C : STA.w $021B
	LDA.w #$0404 : STA.b $1C

	; Scroll down
	LDA #$0100 : STA $E4
	LDA #$0118 : STA $EA
	; Put the main menu onto the stack.
	STZ.w SA1RAM.cm_stack_index
	LDA.w #cm_mainmenu_indices : STA.w SA1RAM.cm_menu_stack
	SEP #$20
	LDA.b #cm_mainmenu_indices>>16 : STA.w SA1RAM.cm_menu_bank_stack
	LDA $9B : AND #$DF : STA $9B
	JSR cm_init_item_variables

.end
	SEP #$20
	INC $11
	RTS


CM_DrawMenu:
	; Save $1000-1680 so we can transfer it back aferwards
	;JSR cm_cache_buffer
	
	PHB
	LDX.w SA1RAM.cm_stack_index
	LDA.w SA1RAM.cm_menu_bank_stack, X
	PHA
	PLB

	%ppu_off()
	JSR cm_transfer_tileset
	JSR cm_redraw_clean
	STZ.w $2121 ; CGRAM 0
	STZ.w $2122 ; black
	STZ.w $2122
	%ppu_on()

	; play sound effect for opening menu
	LDA.b #$14 : STA $012E

	INC $11
	PLB
	RTS


CM_MenuDown:
	LDA #$80 : STA SA1IRAM.TIMER_FLAG
	INC $11
	RTS

CM_Active:
	PHB
	LDX.w SA1RAM.cm_stack_index
	LDA.w SA1RAM.cm_menu_bank_stack, X
	PHA
	PLB

	LDA $B1 : BEQ .in_menu
	JSR cm_do_ctrl_config

	PLB
	RTS

.in_menu
	JSR cm_get_pressed_button
	CPX.b #$04 : BEQ .pressed_down
	CPX.b #$08 : BEQ .pressed_up
	CPX.b #$02 : BEQ .pressed_left
	CPX.b #$01 : BEQ .pressed_right

	; F4 = BYST | udlr
	TXA : AND $F4
	CMP.b #$10 : BEQ .pressed_start
	CMP.b #$20 : BEQ .pressed_select
	CMP.b #$80 : BEQ .pressed_b

	; F6 = AXLR | ....
	TYA : BIT $F6
	BVS .pressed_x
	BMI .pressed_a
	AND $F2 : AND #$30 : BNE .pressed_LR

	; Did not press anything
	BRA .done

.pressed_start
.pressed_select
	; play sound effect for closing menu, and go to next mode
	LDA.b #$15 : STA $012E

	INC $11
	BRA .done

.pressed_up
	REP #$20
	LDX.w SA1RAM.cm_stack_index
	LDA.w SA1RAM.cm_cursor_stack, X : DEC #2
	JSR cm_fix_cursor_wrap
	STA.w SA1RAM.cm_cursor_stack, X
	SEP #$20
	%menubeep()
	BRA .redraw

.pressed_down
	REP #$20
	LDX.w SA1RAM.cm_stack_index
	LDA.w SA1RAM.cm_cursor_stack, X : INC #2
	JSR cm_fix_cursor_wrap
	STA.w SA1RAM.cm_cursor_stack, X
	SEP #$20
	%menubeep()
	BRA .redraw

.pressed_left
.pressed_right
.pressed_a
.pressed_LR
	STZ $72
--	JSR cm_execute_cursor
	BRA .redraw

.pressed_x
	LDA #$01 : STA $72 : BRA --

.pressed_b
	REP #$30
	JSR cm_execute_back
	SEP #$30
	BRA .redraw

.redraw
	JSR cm_redraw

.done
	PLB
	RTS


CM_MenuUp:
	REP #$20
	STZ $E4 : STZ $EA
	SEP #$20

	INC $11

.not_done_scrolling
	RTS


CM_Return:
	REP #$20
	LDA.w $021B : STA.b $1C

	SEP #$20
	INC.b $15

	LDA.w SA1RAM.opened_menu_manually : BEQ .tileset_is_ok
	%ppu_off()
	JSL load_default_tileset
	%ppu_on()

.tileset_is_ok
	STZ.w SA1RAM.opened_menu_manually

	SEP #$30
	LDA.w SA1RAM.preset_type : BEQ .no_preset
	JSL preset_load_next_frame
	RTS

.no_preset
	LDA.w SA1RAM.cm_old_gamemode : STA.b $10
	LDA.w SA1RAM.cm_old_submode : STA.b $11

	; Make sure that the item menu doesn't scroll forever by us resettings EA in previous submodule.
	LDA $10 : CMP.b #$0E : BNE .end
	LDA $11 : CMP.b #$01 : BNE .end
	LDA $0200 : CMP.b #$03 : BCS .item_menu_is_scrolled
	BRA .end

.item_menu_is_scrolled
	REP #$20
	LDA #$FF18 : STA $EA
	SEP #$20

.end
	RTS

; -----------
; Utilities
; ----------

cm_init_item_variables:
	; Crystal Switch state
	LDA $7EC172 : STA.w SA1RAM.cm_old_crystal_switch

	; Bow
	LDA.l !ram_item_bow : BEQ .store_bow
	CMP #$03 : BCC .normal_bow

	LDA.b #$02
	BRA .store_bow

.normal_bow
	LDA.b #$01

.store_bow
	STA.w SA1RAM.cm_item_bow

	; Bottle
	LDA.l !ram_item_bottle : BEQ .store_bottle
	LDA.b #$01
.store_bottle
	STA.w SA1RAM.cm_item_bottle

	; Mirror
	LDA.l !ram_item_mirror : LSR : STA.w SA1RAM.cm_item_mirror

	; MaxHP
	LDA.l !ram_equipment_maxhp
	LSR #3 : DEC #3
	STA.w SA1RAM.cm_equipment_maxhp

	LDA $7EC172 : AND #$01 : STA.l !ram_cm_crystal_switch
	RTS

cm_get_pressed_button:
	REP #$30
	LDA.w SA1IRAM.CONTROLLER_1 : CMP.w SA1RAM.last_frame_input : BEQ .same_as_last_frame

	STA.w SA1RAM.last_frame_input
	PHA
	LDA.w #15 : STA.w SA1RAM.cm_input_timer
	PLA

	; If we're pressing a new button (e.g. holding down v then pressing A), make sure
	; to not do anything that frame (since dpad has priority over face buttons).
	LDA.w SA1IRAM.CONTROLLER_1 : CMP.w SA1IRAM.CONTROLLER_1_FILTERED : BEQ .do_it
	LDA.w #$0000
	BRA .end

.same_as_last_frame
	CMP #$0000 : BEQ .end

	LDA.w SA1RAM.cm_input_timer : DEC : STA.w SA1RAM.cm_input_timer : BNE .no_input

	LDA.w #4 : STA.w SA1RAM.cm_input_timer

.do_it
	LDA.w SA1IRAM.CONTROLLER_1
	BRA .end

.no_input
	LDA #$0000

.end
	TAY
	XBA
	TAX
	SEP #$30
	RTS

cm_clear_stack:
	; Assumes I=8
	;
	; Clears cursor index for all but the main menu.
	REP #$20
	LDX.b #$02
	LDA #$0000

.loop
	STA.w SA1RAM.cm_cursor_stack, X
	STA.w SA1RAM.cm_menu_stack, X
	STA.w SA1RAM.cm_menu_bank_stack, X
	INX #2
	CPX.b #$10 : BNE .loop
	SEP #$20
	RTS


cm_clear_buffer:
	; Assumes I=8
	REP #$20
	LDX.b #$00

	; value of a transparent tile
	LDA #$207F

.loop
	STA.w SA1RAM.MENU+$0000, X : STA.w SA1RAM.MENU+$0080, X
	STA.w SA1RAM.MENU+$0100, X : STA.w SA1RAM.MENU+$0180, X
	STA.w SA1RAM.MENU+$0200, X : STA.w SA1RAM.MENU+$0280, X
	STA.w SA1RAM.MENU+$0300, X : STA.w SA1RAM.MENU+$0380, X
	STA.w SA1RAM.MENU+$0400, X : STA.w SA1RAM.MENU+$0480, X
	STA.w SA1RAM.MENU+$0500, X : STA.w SA1RAM.MENU+$0580, X
	STA.w SA1RAM.MENU+$0600, X : STA.w SA1RAM.MENU+$0680, X
	STA.w SA1RAM.MENU+$0700, X : STA.w SA1RAM.MENU+$0780, X

	INX #2
	CPX.b #$80 : BCC .loop

	SEP #$20
	RTS

cm_transfer_tileset:
	; Assumes A=8
	REP #$10

	; word-access, incr by 1
	LDA #$80 : STA $2115

	LDX #$7000 : STX $2116 ; VRAM address (E000 in vram)
	LDX #cm_hud_table : STX $4302 ; Source offset
	LDA #cm_hud_table>>16 : STA $4304 ; Source bank
	LDX #$0900 : STX $4305 ; Size (0x10 = 1 tile)
	LDA #$01 : STA $4300 ; word, normal increment (DMA MODE)
	LDA #$18 : STA $4301 ; destination (VRAM write)
	LDA #$01 : STA $420B ; initiate DMA (channel 1)

	SEP #$10
	RTS

; ---------
; Draw
; ---------
cm_redraw_clean:
	JSR cm_clear_buffer
cm_redraw:
	; Assumes A=8 I=8
	
	JSR cm_draw_background_gfx
	JSR cm_draw_active_menu

	; tell NMI to update tilemap
	LDA.b #$06 : STA $17

	RTS

cm_draw_background_gfx:
	SEP #$20

	REP #$30
	LDA #$30FB : STA.w SA1RAM.MENU+$0102
	ORA #$8000 : STA.w SA1RAM.MENU+$0742
	ORA #$4000 : STA.w SA1RAM.MENU+$077C
	EOR #$8000 : STA.w SA1RAM.MENU+$013C

	LDX #$0000
	LDY #$0017

.drawVerticalEdges

	LDA.w #$30FC : STA.w SA1RAM.MENU+$0142, X
	ORA.w #$4000 : STA.w SA1RAM.MENU+$017C, X

	TXA : CLC : ADC #$0040 : TAX

	DEY : BPL .drawVerticalEdges

	LDX.w #$0000
	LDY.w #$001B

.drawHorizontalEdges

	LDA.w #$30F9 : STA.w SA1RAM.MENU+$0104, X
	ORA.w #$8000 : STA.w SA1RAM.MENU+$0744, X

	INX #2

	DEY : BPL .drawHorizontalEdges

	LDX.w #$0000
	LDY.w #$001B
	LDA.w #$20F5

.drawBoxInterior

	STA.w SA1RAM.MENU+$0144, X : STA.w SA1RAM.MENU+$0184, X
	STA.w SA1RAM.MENU+$01C4, X : STA.w SA1RAM.MENU+$0204, X
	STA.w SA1RAM.MENU+$0244, X : STA.w SA1RAM.MENU+$0284, X
	STA.w SA1RAM.MENU+$02C4, X : STA.w SA1RAM.MENU+$0304, X
	STA.w SA1RAM.MENU+$0344, X : STA.w SA1RAM.MENU+$0384, X
	STA.w SA1RAM.MENU+$03C4, X : STA.w SA1RAM.MENU+$0404, X
	STA.w SA1RAM.MENU+$0444, X : STA.w SA1RAM.MENU+$0484, X
	STA.w SA1RAM.MENU+$04C4, X : STA.w SA1RAM.MENU+$0504, X
	STA.w SA1RAM.MENU+$0544, X : STA.w SA1RAM.MENU+$0584, X
	STA.w SA1RAM.MENU+$05C4, X : STA.w SA1RAM.MENU+$0604, X
	STA.w SA1RAM.MENU+$0644, X : STA.w SA1RAM.MENU+$0684, X
	STA.w SA1RAM.MENU+$06C4, X : STA.w SA1RAM.MENU+$0704, X

	INX #2

	DEY : BPL .drawBoxInterior

	SEP #$30
	RTS

cm_draw_active_menu:
	; Enters: AI=8
	; Leave with: AI=8
	;
	; This functions sets:
	; $00[0x2] = menu indices
	; $02[0x2] = current menu item index
	; Then we call the action draw method, which can consume its arguments and draw the text however it wants.
	REP #$30
	LDA.w SA1RAM.cm_stack_index
	TAX
	LDA.w SA1RAM.cm_menu_stack, X : STA $00
	LDY #$0000

.loop
	; Figure out if this menu item is on the same location as the cursor.
	TYA : CMP.w SA1RAM.cm_cursor_stack, X : BEQ .selected
	LDA #$0000
	BRA .not_selected

.selected
	LDA #$0010

.not_selected
	STA $0E

	LDA ($00), Y : BEQ .done_with_items : STA $02

	PHY : PHX

	; Pull out the action index, increment $02 so its ready for the associated
	; draw function to use its data however it likes, and jump to it.
	LDA ($02) : TAX
	INC $02 : INC $02
	%jsr_ptr_table(cm_draw_action_table)

	PLX : PLY
	INY #2
	BRA .loop

.done_with_items
	STZ $0E
	TYA : CLC : ADC $00 : INC #2 : STA $02
	LDX #$0186
	JSR cm_draw_text

	SEP #$30
	RTS

cm_draw_text:
	; Assumes I=16
	SEP #$20
	LDY #$0000
	; grab palette info
	LDA ($02), Y : INY : CMP #$FF : BEQ .end
	ORA $0E : STA $0E

.loop
	LDA ($02), Y : CMP #$FF : BEQ .end
	STA.w SA1RAM.MENU, X : INX
	LDA $0E : STA.w SA1RAM.MENU, X : INX
	INY : BRA .loop

.end
	LDA $0E : BIT #$10 : BNE ++
	AND #$FB
++	STA $0D : STZ $0C
	REP #$20
	RTS

; ---------
; Cursor
; ---------

cm_fix_cursor_wrap:
	; Enters: A=16 I=8
	; Leave with: AI=8
	; Assumes: X =.w SA1RAM.cm_stack_index
	;          A = the current cursor position (might be out of bounds)
	;
	; Checks if new cursor is out of bounds, and if so, sets it to the appropriate index.
	REP #$30
	PHA
	LDA.w SA1RAM.cm_menu_stack, X : STA $00
	LDY #$0000

.loop
	LDA ($00), Y : BEQ .after_loop
	INY #2
	BRA .loop

.after_loop
	; Top of stack = cursor index
	; Y = max + 2
	STY $00
	PLA : BMI .set_to_max
	CMP $00 : BEQ .set_to_zero : BCS .set_to_zero

	BRA .end

.set_to_zero
	LDA #$0000
	BRA .end

.set_to_max
	LDA $00
	DEC #2

.end
	SEP #$30
	RTS

cm_execute_cursor:
	; Enters AI=8
	; Leave with AI=8
	;
	; The user selected a menu item.
	REP #$30
	LDX.w SA1RAM.cm_stack_index
	LDA.w SA1RAM.cm_menu_stack, X : STA $00
	LDA.w SA1RAM.cm_cursor_stack, X
	TAY
	LDA ($00), Y : STA $00

	; Consume the action index and jump to the appropriate execute subroutine.
	LDA ($00) : INC $00 : INC $00 : TAX

	%jsr_ptr_table(cm_execute_action_table)
	SEP #$30
	RTS

; ---------------
; Execute Action
; ---------------

cm_execute_action_table:
	; Subroutines for executing an action when the user selects a menu item.
	; Enters: AI=16
	; Can mess with whatever it wants.
	dw cm_execute_toggle
	dw cm_execute_jsr
	dw cm_execute_submenu
	dw cm_execute_back
	dw cm_execute_choice
	dw cm_execute_toggle_jsr
	dw cm_execute_choice_jsr
	dw cm_execute_numfield
	dw cm_execute_preset
	dw cm_execute_toggle_bit
	dw cm_execute_ctrl_shortcut
	dw cm_execute_submenu_variable
	dw cm_execute_movie
	dw cm_execute_toggle_bit

cm_execute_toggle:
	; Will only toggle the first bit.
	LDA ($00) : INC $00 : INC $00 : STA $02
	LDA ($00) : INC $00 : STA $04
	SEP #$30
	LDA $72 : BNE .zero
.toggle
	LDA [$02] : EOR #$01 : BRA ++
.zero
	LDA [$02] : AND #$FE
++	STA [$02]
	PHA
	LDA #$1D : STA $012F ; magic boop
	PLA
	RTS

cm_execute_toggle_jsr:
	LDA ($00) : INC $00 : INC $00 : STA $06
	JSR cm_execute_toggle

	SEP #$30
	LDX.b #$00 : JSR ($0006, X)
	RTS

cm_execute_jsr:
	; < and > should do nothing here
	SEP #$20
	BIT $F2 : BPL .end

	REP #$20
	LDA ($00) : INC $00 : INC $00 : STA $02
	SEP #$20
	LDX #$0000
	JSR ($0002, X)
	SEP #$20
	PHA
	LDA #$25 : STA $012F ; switch sound
	PLA
.end
	RTS

cm_execute_submenu:
	SEP #$20
	LDA $F6 : BPL .end
	LDA #$24 : STA $012F
	; Increments stack index and puts the submenu into the stack.
	REP #$20
	LDA.w SA1RAM.cm_stack_index : INC #2 : STA.w SA1RAM.cm_stack_index : TAX
	LDA ($00) : INC $00 : INC $00 : STA.w SA1RAM.cm_menu_stack, X
	SEP #$20
	LDA ($00) : INC $00 : STA.w SA1RAM.cm_menu_bank_stack, X
	PHA : PLB
	REP #$20

.end
	RTS

cm_execute_back:
	; > should do nothing here
	SEP #$20
	BIT $F0 : BPL .end
	PHA
	LDA #$24 : STA $012F
	PLA
	; Decrements the stack index.
	REP #$20
	; make sure next time we go to a submenu, we start on the first line.
	LDX.w SA1RAM.cm_stack_index
	STZ.w SA1RAM.cm_cursor_stack, X

	; make sure we dont set a negative number
	LDA.w SA1RAM.cm_stack_index : DEC #2 : BPL .done
	LDA #$0000

.done
	STA.w SA1RAM.cm_stack_index
	SEP #$20
	TAX
	LDA.w SA1RAM.cm_menu_bank_stack,x
	PHA
	PLB
	REP #$20

.end
	RTS

cm_execute_choice:
	REP #$20
	LDA ($00) : INC $00 : INC $00 : STA $02
	LDA ($00) : INC $00 : STA $04
	SEP #$30
	LDA $72 : BNE .set_to_zero
	LDA $F0
	CMP #$02 : BEQ .pressed_left
	CMP #$01 : BEQ .pressed_right
	LDA $F6 : CMP #$80 : BEQ .pressed_right
	RTS

.pressed_right
	LDA [$02] : INC : BRA .bounds_check

.pressed_left
	LDA [$02] : DEC

.bounds_check
	TAX         ; X = new value
	LDY.b #$00  ; Y will be set to max

.loop_choices
	LDA ($00) : REP #$20 : INC $00 : SEP #$20 : CMP.b #$FF : BEQ .loop_done

.loop_text
	LDA ($00) : REP #$20 : INC $00 : SEP #$20
	CMP.b #$FF : BNE .loop_text
	INY : BRA .loop_choices

.loop_done
	; X = new value (might be out of bounds)
	; Y = maximum + 2
	; We need to make sure X is between 0-maximum.

	; for convenience so we cna use BCS. We do one more DEC in `.set_to_max`
	; below, so we get the actual max.
	DEY

	TXA : BMI .set_to_max
	STY $06
	CMP $06 : BCS .set_to_zero

	BRA .end

.set_to_zero
	LDA.b #$00 : BRA .end

.set_to_max
	TYA : DEC

.end
	SEP #$30
	STA [$02]
	PHA
	LDA #$1D : STA $012F ; magic boop
	PLA
	RTS

cm_execute_choice_jsr:
	LDA ($00) : INC $00 : INC $00 : STA $08
	JSR cm_execute_choice
	JMP ($0008)

cm_execute_numfield:
	; Puts:
	; memory address in $02[0x3]
	; min in $05[0x1]
	; max in $06[0x1]
	; increment value in $07[0x1]
	PHX
	PHY
	PHP
	REP #$20
	LDA ($00) : INC $00 : INC $00 : STA $02
	LDA ($00) : INC $00 : INC $00 : STA $04
	; One additional INC on the max value here, for convenience later.
	LDA ($00) : INC $00 : INC $00 : INC : STA $06
	TAY ; for comparison for FF
	SEP #$30

	LDA $72 : BNE .set_to_min
	LDA $F0 : AND #$03
	ORA $F2 : AND #$33
		BIT #$01 : BNE .pressed_right
		BIT #$02 : BNE .pressed_left
		BIT #$10 : BNE .pressed_R_shoulder
		BIT #$20 : BNE .pressed_L_shoulder
	BRA .quit

.pressed_R_shoulder
	LDA [$02] : CLC : ADC $07
	CPY #$00 : BEQ ++ ; skip boundaries if max=FF
	CMP $06 : BCS .set_to_max
	BRA ++

.pressed_right
	LDA [$02] : CLC : ADC #$01
	CPY #$00 : BEQ ++ ; skip boundaries if max=FF
	CMP $06 : BCS .set_to_min
++	STA [$02] : BRA .end

.pressed_L_shoulder
	LDA [$02] : SEC : SBC $07
	CMP $05 : BMI .set_to_min : BCC .set_to_min
	BRA ++

.pressed_left
	LDA [$02] : SEC : SBC #$01
	CMP $05 : BMI .set_to_max : BCC .set_to_max

++	STA [$02] : BRA .end

.set_to_min
	LDA $05 : STA [$02] : CLC : BRA .end

.set_to_max
	LDA $06 : DEC : STA [$02] : CLC

.end
	PHA
	LDA #$1D : STA $012F ; magic boop
	PLA
.quit
	PLP
	PLY
	PLX
	RTS

cm_execute_preset:
	LDA $F0 : BNE .end

	REP #$20
	LDA ($00) : STA $02
	INC
	STA.w SA1RAM.preset_destination
	STA.w SA1RAM.previous_preset_destination
	SEP #$30
	PHB
	LDX.w !ram_preset_category
	LDA.l cm_preset_data_banks, X : PHA : PLB
	LDA ($02)
	STA.w SA1RAM.preset_type
	STA.w SA1RAM.previous_preset_type
	PLB
	INC $11
.end
	REP #$30
	RTS

cm_preset_data_banks:
	db sram_nmg_esc_bed>>16
	db sram_hundo_esc_bed>>16
	db sram_lownmg_esc_bed>>16
	db sram_low_esc_bed>>16
	db sram_ad2020_east_bed>>16
	db sram_ad_esc_links_bed>>16
	db sram_anyrmg_east_bed>>16

cm_execute_toggle_bit:
	; Load the address
	LDA ($00) : INC $00 : INC $00 : STA $02
	LDA ($00) : INC $00 : STA $04
	; Load which bit(s) to toggle
	LDA ($00) : INC $00 : STA $05
	SEP #$30
	LDA [$02] : EOR $05 : STA [$02]
	PHA
	LDA #$1D : STA $012F ; magic boop
	PLA
	RTS

cm_execute_ctrl_shortcut:
	; < and > should do nothing here
	SEP #$20

	; check if we pressed X or A
	BIT $F6
	BMI .continue
	BVC .end

.continue
	REP #$20
	LDA ($00) : STA $35 : INC $00 : INC $00
	LDA ($00) : STA $37 : INC $00
	LDA #!ram_ctrl_prachack_menu : CMP $35 : BEQ .end

	SEP #$20
	BIT $F6 : BVS .reset_shortcut

	INC $B1
	STZ $0200
	BRA .end

.reset_shortcut
	REP #$20

	LDA #$0000 : STA [$35]

.end
	REP #$20
	RTS

cm_execute_submenu_variable:
	; dpad should do nothing here
	SEP #$20
	LDA $F0 : BNE .end
	LDA #$24 : STA $012F

	; Increments stack index and puts the submenu into the stack.
	REP #$20
	LDA.w SA1RAM.cm_stack_index : INC #2 : STA.w SA1RAM.cm_stack_index : TAX

	LDA ($00) : STA $02 : INC $00 : INC $00
	LDA ($00) : STA $04 : INC $00

	; get max index + 1
	LDA ($00) : AND #$00FF : STA $05 : INC $00

	LDA [$02] : AND #$00FF
	CMP $05 : BCC .in_range

	; failsafe
	LDA $05 : DEC

.in_range
	STA $07
	ASL
	ADC $07
	TAY
	LDA ($00), Y
	STA.w SA1RAM.cm_menu_stack,X
	INY
	INY
	SEP #$20
	LDA ($00), Y
	STA.w SA1RAM.cm_menu_bank_stack, X
	PHA
	PLB
	REP #$20

	LDA $05
	ASL
	ADC $05
	ADC $00
	STA $00

.end
	RTS

cm_execute_movie:
	LDA #$0000
	LDX #$0000
	SEP #$20
	; dpad should do nothing here
	LDA $F0 : BNE .end

	; Grab slot
	LDA ($00) : ASL #4 : TAX

	LDA $F6 : CMP #$40 : BEQ .delete_movie
	LDA !sram_movies, X : BEQ .save

.load
	REP #$20
	JSR cm_movie_load
	BRA .end

.save
	REP #$20
	LDA !ram_movie_length : BEQ .error
	JSR cm_movie_save
	BRA .end

.delete_movie
	REP #$20
	LDA !sram_movies, X : BEQ .error
	JSR cm_movie_delete
	BRA .end

.error
	SEP #$20
	PHA
	LDA #$3C : STA $012E
	PLA
.end
	REP #$30
	RTS

; -------------
; Draw Action
; -------------

cm_draw_action_table:
	; Subroutines for drawing a menu item. I choose to do a subroutine dispatch for this,
	; to make it possible for some widgets to draw itself differently (e.g. checkboxes, comboboxes etc).
	;
	; Enters: AI=16, Y=row number * 2
	; Leave with: AI=16, $00[0x2]

	dw cm_draw_toggle
	dw cm_draw_jsr
	dw cm_draw_submenu
	dw cm_draw_back
	dw cm_draw_choice
	dw cm_draw_toggle_jsr
	dw cm_draw_choice_jsr
	dw cm_draw_numfield
	dw cm_draw_preset
	dw cm_draw_toggle_bit
	dw cm_draw_ctrl_shortcut
	dw cm_draw_submenu_variable
	dw cm_draw_movie
	dw cm_draw_toggle_bit_customtext


macro item_index_to_vram_index()
	; Assumes AI=16
	; Messes with A, X
	;
	; Find screen position from Y (item number)
	TYA : ASL #5
	CLC : ADC #$0206 : TAX
endmacro


cm_draw_toggle:
	; grab the memory address (long)
	LDA ($02) : INC $02 : INC $02 : STA $04
	LDA ($02) : INC $02 : STA $06

	; Draw the text first (since it uses A)
	%item_index_to_vram_index() : PHX
	JSR cm_draw_text
	PLX
	%set_menu_icon($4B)

	; Set position for ON/OFF
	TXA : CLC : ADC.w #!OPTION_OFFSET : TAX

	SEP #$20
	; set palette
	LDA $0E
	STA.w SA1RAM.MENU+1, X
	STA.w SA1RAM.MENU+3, X
	STA.w SA1RAM.MENU+5, X

	; grab the value at that memory address
	LDA [$04] : BNE .checked

	; No
	LDA.b #$0D : STA.w SA1RAM.MENU+0, X
	LDA.b #$38 : STA.w SA1RAM.MENU+2, X

	BRA .end

.checked
	; Yes
	LDA.b #$18 : STA.w SA1RAM.MENU+0, X
	LDA.b #$2E : STA.w SA1RAM.MENU+2, X
	LDA.b #$3C : STA.w SA1RAM.MENU+4, X

.end
	REP #$20
	RTS


cm_draw_toggle_jsr:
	; just skip the JSR address
	INC $02 : INC $02
	JSR cm_draw_toggle
	RTS


cm_draw_jsr:
	; skip jsr address
	INC $02 : INC $02

	; draw text normally
	%item_index_to_vram_index() : PHX
	JSR cm_draw_text
	PLX
	%set_menu_icon($4A)
	RTS


cm_draw_submenu:
	INC $02 : INC $02 : INC $02 ; skip submenu address

.from_var
	; draw text normally
	%item_index_to_vram_index() : PHX
	JSR cm_draw_text
	PLX
	%set_menu_icon($49)
	RTS


cm_draw_back:
	; just draw the text
	%item_index_to_vram_index()
	JSR cm_draw_text
	RTS


cm_draw_toggle_bit_customtext:
	; grab the memory address (long)
	LDA ($02) : INC $02 : INC $02 : STA $04
	LDA ($02) : INC $02 : STA $06
	; grab bitmask
	LDA ($02) : INC $02 : STA $07

	; Draw the text first (since it uses A)
	%item_index_to_vram_index() : PHX
	JSR cm_draw_text
	PLX
	%set_menu_icon($4B)

	; set position for ON/OFF
	TXA : CLC : ADC.w #!OPTION_OFFSET : TAX

	LDA #$0000
	LDY #$0000
	; grab the value at that memory address

	LDA [$04] : AND $07 : AND #$00FF
	BEQ ++
	INY
++	BRA cm_draw_choice_findText

cm_draw_choice:
	; grab the memory address (long)
	LDA ($02) : INC $02 : INC $02 : STA $04
	LDA ($02) : INC $02 : STA $06

	; Draw the text first (since it uses A)
	%item_index_to_vram_index()
	PHX
	JSR cm_draw_text
	PLX
	%set_menu_icon($4C)

	; set position for ON/OFF
	TXA : CLC : ADC.w #!OPTION_OFFSET : TAX

	LDY #$0000
	LDA #$0000
	; grab the value at that memory address
	LDA [$04] : AND #$00FF : TAY

.findText
	; find the correct text that should be drawn (the selected choice)
	INY #2 ; uh, skipping the first text that we already draw..
.loop_choices
	DEY : BEQ .found

.loop_text
	LDA ($02) : INC $02 : AND #$00FF
	CMP.w #$00FF : BEQ .loop_choices
	BRA .loop_text

.found
	JSR cm_draw_text
	REP #$20
	RTS


cm_draw_choice_jsr:
	; just skip the JSR address
	INC $02 : INC $02
	JSR cm_draw_choice
	RTS


cm_draw_numfield:
	; grab the memory address (long)
	LDA ($02) : INC $02 : INC $02 : STA $04
	LDA ($02) : INC $02 : STA $06

	; skip bounds and increment value
	INC $02 : INC $02 : INC $02

	; Draw the text
	%item_index_to_vram_index()
	PHX
	JSR cm_draw_text
	PLX
	%set_menu_icon($4D)

	; set position for the number
	TXA : CLC : ADC.w #!OPTION_OFFSET : TAX

	PHX
	LDA [$04] : AND #$00FF : JSL hex_to_dec_snes
	PLX

	; Clear out the area (black tile)
	LDA #$24F5
	STA.w SA1RAM.MENU+0, X
	STA.w SA1RAM.MENU+2, X
	STA.w SA1RAM.MENU+4, X

	; Set palette
	SEP #$20
	LDA.b #$24 : ORA $0E : STA $0F
	LDA.b #$20 : STA $0E
	REP #$20

	; Draw numbers
	LDA.w SA1RAM.hex2dec_first_digit : BEQ .second_digit
	CLC : ADC $0E : STA.w SA1RAM.MENU+0, X
	INX #2

.second_digit
	LDA.w SA1RAM.hex2dec_second_digit : BEQ .third_digit
	CLC : ADC $0E : STA.w SA1RAM.MENU+0, X
	INX #2

.third_digit
	LDA.w SA1RAM.hex2dec_third_digit : CLC : ADC $0E
	STA.w SA1RAM.MENU+0, X

	RTS

cm_draw_preset:
	REP #$20
	INC $02 : INC $02
	%item_index_to_vram_index() : PHX
	JSR cm_draw_text
	PLX
	%set_menu_icon($4E)

	RTS


cm_draw_toggle_bit:
	; grab the memory address (long)
	LDA ($02) : INC $02 : INC $02 : STA $04
	LDA ($02) : INC $02 : STA $06
	; grab bitmask
	LDA ($02) : INC $02 : STA $07

	; Draw the text first (since it uses A)
	%item_index_to_vram_index() : PHX
	JSR cm_draw_text
	PLX
	%set_menu_icon($4B)

	; set position for ON/OFF
	TXA : CLC : ADC.w #!OPTION_OFFSET : TAX

	SEP #$20
	; set palette
	LDA $0E
	STA.w SA1RAM.MENU+1, X
	STA.w SA1RAM.MENU+3, X
	STA.w SA1RAM.MENU+5, X

	; grab the value at that memory address
	LDA [$04] : AND $07 : BNE .checked

	; No
	LDA.b #$0D : STA.w SA1RAM.MENU+0, X
	LDA.b #$38 : STA.w SA1RAM.MENU+2, X

	BRA .end

.checked
	; Yes
	LDA.b #$18 : STA.w SA1RAM.MENU+0, X
	LDA.b #$2E : STA.w SA1RAM.MENU+2, X
	LDA.b #$3C : STA.w SA1RAM.MENU+4, X

.end
	REP #$20
	RTS

cm_draw_ctrl_shortcut:
	LDA ($02) : STA $04 : INC $02 : INC $02
	LDA ($02) : STA $06 : INC $02

	PHY
	%item_index_to_vram_index()
	PHX
	JSR cm_draw_text
	PLX
	%set_menu_icon($4F)
	PLY

	REP #$30
	TYA : ASL #5
	CLC : ADC #$022A : TAX

	LDA #$2480 : STA $0E
	LDA [$04]
	JSR cm_ctrl_input_display

	RTS


cm_draw_submenu_variable:
	; skip var address
	INC $02 : INC $02 : INC $02

	; get (max index + 1) * 3
	LDA ($02)
	AND #$00FF
	STA $04
	ASL
	ADC $04
	STA $04
	INC $02

	; skip submenu pointers
	LDA $02 : CLC : ADC $04 : STA $02

	JMP cm_draw_submenu_from_var


cm_draw_movie: RTS
  PHY
    LDA ($02) : INC $02 : AND #$00FF : ASL #4 : TAX
    LDA !sram_movies, X : PHA

    BNE .normalColor
    LDA $0E : BNE .normalColor
    LDA #$0020 : STA $0E
    BRA .drawItem

  .normalColor
    LDA #$0024 : ORA $0E : STA $0E

  .drawItem
    %item_index_to_vram_index()
    JSR cm_draw_text
  PLY

    CPY #$0000 : BEQ .emptyFile

    DEX #22

    LDA $0E : ASL #8 : STA $06
    TYA : LSR #12 : AND #$000F : ORA #$0020 : ORA $06 : STA $1000, X : INX #2
    TYA : LSR #8 : AND #$000F : ORA #$0020 : ORA $06 : STA $1000, X : INX #2
    TYA : LSR #4 : AND #$000F : ORA #$0020 : ORA $06 : STA $1000, X : INX #2
    TYA : AND #$000F : ORA #$0020 : ORA $06 : STA $1000, X : INX #2
    BRA .end

  .emptyFile
    DEX #22
    LDA #.emptyFileText : STA $02
    JSR cm_draw_text

  .end
  PLY
    CPY #$0000 : BEQ .drawInstructions
    RTS

  .drawInstructions
    STZ $0E

    LDX #$0646
    LDA #.instruction1 : STA $02
    JSR cm_draw_text

    LDX #$0686
    LDA #.instruction2 : STA $02
    JSR cm_draw_text

    LDX #$0198
    LDA #.bytesLeftText : STA $02
    JSR cm_draw_text

    DEX #8

  PHX
    JSR cm_movie_get_bytes_left : TAY
  PLX

    TYA : LSR #12 : AND #$000F : ORA #$2420 : STA $1000, X : INX #2
    TYA : LSR #8 : AND #$000F : ORA #$2420 : STA $1000, X : INX #2
    TYA : LSR #4 : AND #$000F : ORA #$2420 : STA $1000, X : INX #2
    TYA : AND #$000F : ORA #$2420 : STA $1000, X : INX #2

    RTS

  table ../resources/normal.tbl
  .emptyFileText
    db $20, "empty)      ", #$FF
  .bytesLeftText
    db $24, "Space left 0000", #$FF
  .instruction1
    db $24, "A  Load or Save", #$FF
  .instruction2
    db $24, "X  Delete", #$FF



; -----------
; Ctrl config
; -----------

cm_ctrl_input_display:
	; X = pointer to tilemap area (STA $1000, X)
	; A = Controller word
	JSR cm_ctrl_clear_input_display

	LDY #$0000
	XBA
.loop
	PHA
	AND #$0001 : CMP #$0001 : BNE .no_draw

	TYA : CLC : ADC $0E
	STA.w SA1RAM.MENU+0, X : INX : INX

.no_draw
	PLA
	LSR : INY : CPY #$0010 : BEQ .done
	BRA .loop

.done
	RTS


cm_ctrl_clear_input_display:
	; X = pointer to tilemap area
	PHA
	LDA #$24F5
	STA.w SA1RAM.MENU+$00, X
	STA.w SA1RAM.MENU+$02, X
	STA.w SA1RAM.MENU+$04, X
	STA.w SA1RAM.MENU+$06, X
	STA.w SA1RAM.MENU+$08, X
	STA.w SA1RAM.MENU+$0A, X
	STA.w SA1RAM.MENU+$0C, X
	STA.w SA1RAM.MENU+$0E, X
	STA.w SA1RAM.MENU+$10, X
	PLA
	RTS


cm_do_ctrl_config:
	; Enters AI=8
	; Leaves AI=8
	REP #$20
	LDA #$2080 : STA $0E
	LDA.w SA1IRAM.CONTROLLER_1 : BEQ .clear_and_draw
	CMP.w SA1RAM.ctrl_last_input : BNE .clear_and_draw

	; Holding an input for more than 1f
	LDA $0200 : INC : STA $0200 : CMP.w #0060 : BNE .next_frame

	LDA.w SA1IRAM.CONTROLLER_1 : STA [$35]
	BRA .exit

.clear_and_draw
	STA.w SA1RAM.ctrl_last_input
	STZ $0200

.draw

	REP #$30
	; Put text cursor in X
	LDX.w SA1RAM.cm_stack_index
	LDY.w SA1RAM.cm_cursor_stack, X
	TYA

	ASL #5
	CLC : ADC #$022A : TAX

	; Input display
	LDA.w SA1IRAM.CONTROLLER_1
	JSR cm_ctrl_input_display

	SEP #$30
	LDA.b #$06 : STA $17

.next_frame
	SEP #$30
	RTS

.exit
	STZ.w SA1RAM.ctrl_last_input

	SEP #$30
	STZ $B1
	STZ $0200
	JSR cm_redraw
	RTS


; ------
; Movie
; ------

cm_movie_get_bytes_left:
	LDA #!sram_movie_data_size
	LDX #$00F0

.loop
	SEC : SBC.l !sram_movies_length, X
	DEX #$10 : BPL .loop

	RTS


cm_movie_get_next_offset:
	; Enter: AI=16
	; Leave: AI=16
	; X & Y = new slot
	PHX
	TXY

	LDA #$0000 : STA $06 : STA $08 : STA $0A

	LDX #$0100
.loop
	TXA : SEC : SBC #$0010 : TAX : BMI .done
	LDA !sram_movies_length, X : BEQ .loop
	INC $0A
	LDA !sram_movies_offset, X
	CMP $06 : BCC .loop
	STA $06 : STX $08
	BRA .loop

.done
	LDA $0A : BEQ .firstMovie

	LDA $08 : TYX : STA !sram_movies_prev_slot, X
	LDX $08
	TYA : STA !sram_movies_next_slot, X
	LDA $06 : CLC : ADC !sram_movies_length, X
	PLX

	RTS

.firstMovie
	PLX
	LDA #$FFFF : STA !sram_movies_prev_slot, X : STA !sram_movies_next_slot, X
	LDA #$0000
	RTS


cm_movie_save:
	; Enter: AI=16
	; X = movie slot
	JSR cm_movie_get_next_offset

	PHA

	LDA !ram_movie_length : STA !sram_movies_input_length, X
	CLC : ADC !ram_movie_rng_length : STA !sram_movies_length, X
	LDA !ram_movie_rng_length : STA !sram_movies_rng_length, X
	LDA #$FFFF : STA !sram_movies_next_slot, X

	SEP #$20 : LDA.w !ram_previous_preset_type : STA !sram_movies_preset_type, X : REP #$20
	LDA.w !ram_previous_preset_destination : STA !sram_movies_preset_destination, X

	PLA : STA !sram_movies_offset, X

	SEP #$20 : LDA !ram_movie_framecounter : STA !sram_movies_frame_counter, X : REP #$20

	LDA.w #!ram_movie : STA $06
	LDA.w #!ram_movie>>16 : STA $08

	LDA.w #!sram_movie_data : CLC : ADC !sram_movies_offset, X : STA $09
	LDA.w #!sram_movie_data>>16 : STA $0B

	LDX !ram_movie_length : DEX
.movieLoop
	LDA [$06] : STA [$09]
	INC $06 : INC $06
	INC $09 : INC $09
	DEX #2 : BPL .movieLoop

	LDA #$DD00 : SEC : SBC !ram_movie_rng_length : STA $06

	LDX !ram_movie_rng_length : DEX
.rngLoop
	LDA [$06] : STA [$09]
	INC $06 : INC $06
	INC $09 : INC $09
	DEX #2 : BPL .rngLoop

	RTS

cm_movie_delete:
	; Enter: AI=16
	; X = movie slot to delete
	LDA !sram_movies_prev_slot, X : STA $06
	LDA !sram_movies_next_slot, X : STA $08
	LDA !sram_movies_length, X : TAY

	PHX
	LDX $06
	LDA $08 : STA !sram_movies_next_slot, X
	LDX $08
	LDA $06 : STA !sram_movies_prev_slot, X

	JSR .recurse
	PLX

	LDA #$0000
	STA !sram_movies_length, X
	STA !sram_movies_input_length, X
	STA !sram_movies_rng_length, X
	STA !sram_movies_offset, X
	STA !sram_movies_frame_counter, X
	STA !sram_movies_prev_slot, X
	STA !sram_movies_next_slot, X
	STA !sram_movies_preset_type, X
	STA !sram_movies_preset_destination, X
	RTS

.recurse
	; X = slot to move
	; Y = the distance to move it
	CPX #$FFFF : BEQ .done

	PHY
	TYA : STA $0D

	LDA.w #!sram_movie_data : CLC : ADC !sram_movies_offset, X : STA $06
	LDA.w #!sram_movie_data>>16 : STA $08 : STA $0B
	LDA $06 : SEC : SBC $0D : STA $09

	LDA !sram_movies_length, X : TAY
.loop
	LDA [$06] : STA [$09]
	INC $06 : INC $06
	INC $09 : INC $09
	DEY #2 : BPL .loop
	PLY

	LDA !sram_movies_offset, X : SEC : SBC $0D : STA !sram_movies_offset, X
	LDA !sram_movies_next_slot, X : TAX
	JSR .recurse

.done
	RTS

cm_movie_load:
	; Enter: AI=16
	; X = movie slot
	LDA !sram_movies_input_length, X : STA !ram_movie_length
	LDA !sram_movies_rng_length, X : STA !ram_movie_rng_length
	SEP #$20 : LDA !sram_movies_frame_counter, X : STA !ram_movie_framecounter : REP #$20

	SEP #$20 : LDA !sram_movies_preset_type, X : STA.w !ram_previous_preset_type : REP #$20
	LDA !sram_movies_preset_destination, X : STA.w !ram_previous_preset_destination

	LDA.w #!sram_movie_data : CLC : ADC !sram_movies_offset, X : STA $06
	LDA.w #!sram_movie_data>>16 : STA $08

	LDA.w #!ram_movie : STA $09
	LDA.w #!ram_movie>>16 : STA $0B

	LDY !ram_movie_length : DEY
.movieLoop
	LDA [$06] : STA [$09]
	INC $06 : INC $06
	INC $09 : INC $09
	DEY #2 : BPL .movieLoop

	LDA #$DD00 : SEC : SBC !ram_movie_rng_length : STA $09

	LDY !ram_movie_rng_length : DEY
.rngLoop
	LDA [$06] : STA [$09]
	INC $06 : INC $06
	INC $09 : INC $09
	DEY #2 : BPL .rngLoop

	LDA #$0002 : STA !ram_movie_next_mode
	LDA.w SA1RAM.previous_preset_destination : STA.w SA1RAM.preset_destination
	SEP #$20
	LDA.w SA1RAM.previous_preset_type : STA.w SA1RAM.preset_type
	LDA #$04 : STA $11
	REP #$20
	RTS


; ------
; Data
; ------

incsrc cm_mainmenu.asm