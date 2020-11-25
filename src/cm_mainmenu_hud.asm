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
;	dw cm_hud_lagometer
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

cm_hud_lagometer:
	%cm_toggle_jsr("Lagometer", !ram_lagometer_toggle)

.toggle
	REP #$20
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
	REP #$20
	LDA #$0000
	STA !ram_lanmola_cycles
	STA !ram_lanmola_cycles+2
	STA !ram_lanmola_cycles+4
	SEP #$20
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
	PHP
	PHB

	JSL ClearSWBuffer
	JSL CleanVRAMSW

	SEP #$20
	LDA.l !ram_superwatch
	ASL
	TAX

	JSR (.togglesss, X)

	PLB
	PLP
	RTS

.togglesss
	dw .off
	dw .ancillae
	dw .doorwatch

.off
	STZ.b !ram_extra_sa1_required
	RTS

.ancillae
	LDA.b #$01
	STA.b !ram_extra_sa1_required
	RTS

.doorwatch
	SEP #$20
	REP #$10

	; Use HDMA channel 5
	LDA #%00000010 : STA $4350 ; direct, 1 address, 2 writes
	LDA #$11 : STA $4351 ; BG3 h scroll
	LDX.w #..doorwatchhdma : STX $4352 ; address of table
	LDA.b #..doorwatchhdma>>16 : STA $4354 ; bank of table

	LDA.b #$01
	STA.b !ram_extra_sa1_required
	RTS

..doorwatchhdma
	db 63 : dw 0
	db 32 : dw 256
	db 1 : dw 0
	db 0

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