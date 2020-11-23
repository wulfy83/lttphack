; HUD EXTRAS {{{

cm_main_goto_hud:
	%cm_submenu("HUD extras", cm_submenu_hud)

cm_submenu_hud:
	dw cm_hud_input_display
	dw cm_hud_real
	dw cm_hud_lag
	dw cm_hud_heartlag
	dw cm_hud_idle
	dw cm_hud_segment
	dw cm_hud_xy
	dw cm_hud_qw
	dw cm_hud_ramwatch
	dw cm_hud_superwatch
	dw cm_hud_lanmola_cycle_count
	dw cm_hud_lagometer
	dw cm_hud_enemy_hp
	dw !menu_end
	%cm_header("HUD EXTRAS")

cm_hud_real:
	%cm_toggle("Room time", !ram_counters_real)

cm_hud_lag:
	%cm_toggle("Lag counter", !ram_counters_lag)

cm_hud_heartlag:
	%cm_toggle("Heart lag", !ram_heartlag_spinner)

cm_hud_idle:
	%cm_toggle("Idle frames", !ram_counters_idle)

cm_hud_segment:
	%cm_toggle("Segment time", !ram_counters_segment)

cm_hud_xy:
	dw !CM_ACTION_CHOICE
	dl !ram_xy_toggle
	%cm_item("Coordinates")
	%cm_item("Off")
	%cm_item("3 digits")
	%cm_item("4 digits")
	db !list_end

;	dw !CM_ACTION_CHOICE
;	dl !ram_xy_toggle
;	%cm_item("Coordinates")
;	%cm_item("No")
;	%cm_item("Hexadecimal")
;	%cm_item("Decimal")
;	db !list_end

;cm_hud_subpixels:
;	dw !CM_ACTION_CHOICE
;	dl #!ram_subpixels_toggle
;	%cm_item("Subpixels")
;	%cm_item("No")
;	%cm_item("Subpixels")
;	%cm_item("Speed")
;	db !list_end

cm_hud_lagometer:
	%cm_toggle_jsr("Lagometer", !ram_lagometer_toggle)

.toggle
	%a16()
	LDA #$207F : STA.w SA1HUD+$42 : STA.w SA1HUD+$82 : STA.w SA1HUD+$C2 : STA $7EC802
	RTS

cm_hud_input_display:
	dw !CM_ACTION_CHOICE
	dl !ram_input_display
	%cm_item("Input display")
	%cm_item("Off")
	%cm_item("Graphical")
	%cm_item("Classic")
	db !list_end

cm_hud_enemy_hp:
	%cm_toggle_jsr("Enemy HP", !ram_enemy_hp_toggle)

cm_hud_qw:
	%cm_toggle("QW indicator", !ram_qw_toggle)

cm_hud_ramwatch:
	dw !CM_ACTION_CHOICE
	dl !ram_extra_ram_watch
	%cm_item("RAM watch")
	%cm_item("Off")
	%cm_item("Subpixels")
	%cm_item("Spooky altit")
	%cm_item("Arc variable")
	%cm_item("Icebreaker")
	db !list_end

cm_hud_lanmola_cycle_count:
	%cm_toggle_jsr("Lanmola cycs", !ram_toggle_lanmola_cycles)

.toggle
	%a16()
	LDA #$0000
	STA !ram_lanmola_cycles
	STA !ram_lanmola_cycles+2
	STA !ram_lanmola_cycles+4
	%a8()
	RTS

cm_hud_superwatch:
	dw !CM_ACTION_CHOICE_JSR
	dw .toggle
	dl !ram_superwatch
	%cm_item("Super Watch")
	%cm_item("Off")
	%cm_item("Ancillae")
	%cm_item("UW Glitches")
	db !list_end

.toggle

	JSL ClearWatchBuffer

	PHP : PHB
	; wait for vblank
	SEP #$30
	LDA.b #$80
	STA.w $2100
	REP #$30
	LDA.w #$C200>>1 ; tile map location of BG3 
	STA.w $2116
	LDX.w #$140
	LDA.w #$207F
--	STA.w $2118
	DEX
	BNE --

	%a8()
	LDA !ram_superwatch : CMP #$02 : BNE ++

	%i16()
	PEA.w (!dg_hdma>>16)&$00FF ; Pushes bank $00 then bank $7F (probably)
	PLB ; bank of the hdma table for modifying

	; Set up the HDMA table
	LDA.b #63 : STA.w !dg_hdma+0 ; for 64 scanlines
	LDX.w #$0000 : STX.w !dg_hdma+1 ; Shift BG3 by 0 pixels

	LDA.b #32 : STA.w !dg_hdma+3 ; for 32 scanlines
	LDX #$0100 : STX.w !dg_hdma+4 ; shift BG3 by 256 pixels

	LDA.b #$01 : STA.w !dg_hdma+6 ; for 1 scanline
	LDX.w #$0000 : STX.w !dg_hdma+7 ; shift BG3 by 0 pixels

	STZ.w !dg_hdma+9 ; terminate HDMA

	PLB ; bank 0, where we have register/bank $7E mirrors

	; Use HDMA channel 5
	LDA #%00000010 : STA $4350 ; direct, 1 address, 2 writes
	LDA #$11 : STA $4351 ; BG3 h scroll
	LDX.w #!dg_hdma : STX $4352 ; address of table
	LDA.b #!dg_hdma>>16 : STA $4354 ; bank of table

	PLB : PLP
	RTS

++	PLB : PLP

SA1ExtraTransfersField:
cm_hud_enemy_hp_toggle:
	PHP
	SEP #$20
	LDA.l !ram_superwatch
	ORA.l !ram_extra_ram_watch
	ORA.l !ram_enemy_hp_toggle

	STA.b !ram_extra_sa1_required
	PLP
	RTS

; }}}