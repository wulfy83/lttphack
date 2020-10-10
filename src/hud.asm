pushpc
; -------------
; HUD TEMPLATE
; -------------

; HUD Template Hijack
;
; Overrides the following
; $0DFA8E: E2 30  SEP #$30
; $0DFA90: E6 16  INC $16
org $0DFAAE
	JSL hud_template_hook

org $0DFD0A
	JSL HUDCanUpdate
	RTS
pullpc

HUDCanUpdate:
	STA.l SA1HUD+$064
	CMP.w #$247F
	BNE ++
	STA.l SA1HUD+$024
++	SEP #$30

	
	RTL

; Hud Template Hook
hud_template_hook:
	; Makes sure to redraw hearts.
	%a8()
	INC $16
	RTL

WasteTimeWithHearts:
	NOP ; never remove this, it's part of vanilla cycle count
	RTL

heart_lag_extra:

update_hearts_hook:

	%ai8()
	JSL UpdateGlitchedWindow

++	%ai16()
	; Enters: AI=16
	; Keep AI=16 throughout (let subroutines change back/forth)
	JSR hud_draw_hearts

	%a16()
	LDA !ram_enemy_hp_toggle : BEQ .dont_draw_enemy_hp

	JSR hud_draw_enemy_hp

.dont_draw_enemy_hp

	;LDA !ram_misslots_toggle : BEQ .dont_update_misslots

	;JSR hud_draw_misslots

.dont_update_misslots
	%a8()
	LDA !ram_lit_rooms_toggle : BEQ .dont_update_lit_rooms
	LDA #$03 : STA $045A

.dont_update_lit_rooms
	LDA !ram_toggle_lanmola_cycles : BEQ .end

	; Make sure we're indoors and in the boss fight room
	LDA $A0 : CMP.b #$33 : BNE .end
	LDA $1B : BEQ .end

	LDA $0DF0 : CMP.b #$01 : BNE .lanmola2
	LDA $0D80 : CMP.b #$01 : BNE .lanmola2
	LDA !ram_lanmola_cycles : INC : STA !ram_lanmola_cycles+0

.lanmola2
	LDA $0DF1 : CMP.b #$01 : BNE .lanmola3
	LDA $0D81 : CMP.b #$01 : BNE .lanmola3
	LDA !ram_lanmola_cycles+1 : INC : STA !ram_lanmola_cycles+1

.lanmola3
	LDA $0DF2 : CMP.b #$01 : BNE .draw_cycles
	LDA $0D82 : CMP.b #$01 : BNE .draw_cycles
	LDA !ram_lanmola_cycles+2 : INC : STA !ram_lanmola_cycles+2

.draw_cycles
	%a16()
	JSR hud_draw_lanmola_cycles

.end
	%ai16()
	RTL


hud_draw_lanmola_cycles:
	LDA !ram_lanmola_cycles+0 : AND #$00FF : ORA #$2010 : STA $7EC810
	LDA !ram_lanmola_cycles+1 : AND #$00FF : ORA #$2010 : STA $7EC812
	LDA !ram_lanmola_cycles+2 : AND #$00FF : ORA #$2010 : STA $7EC814
	RTS

hud_draw_hearts:
	; Assumes: X=16

	; Check if we have full hp
	SEP #$21
	REP #$10
	LDA.w SA1IRAM.CopyOf_7EF36C : SBC.w SA1IRAM.CopyOf_7EF36D : CMP.b #$04

	%a16()
	LDA #$24A0 ; keep cycles similar
	ADC #$0000 ; give us $2A41 if carry was set for not full HP

	; Heart gfx
	STA !POS_MEM_HEART_GFX

	; Full hearts
	LDA.w SA1IRAM.CopyOf_7EF36D : AND #$00FF : LSR #3 : JSL hex_to_dec
	LDA.b SA1IRAM.SCRATCH+2 : ORA #$3C90 : STA.w SA1HUD+$000+!POS_HEARTS
	LDA.b SA1IRAM.SCRATCH+4 : ORA #$3C90 : STA.w SA1HUD+$002+!POS_HEARTS

	; Quarters
	LDA.w SA1IRAM.CopyOf_7EF36D : AND #$0007 : ORA #$3490 : STA.w SA1HUD+$004+!POS_HEARTS

	; Heart lag spinner
	LDA.w SA1IRAM.CopyOf_1A : AND #$000C
	XBA : ASL #4
	ORA #$253F
	TAY
	LDA.l !ram_heartlag_spinner : BEQ ++
	TYA
	STA !POS_MEM_HEARTLAG
	BRA +

++	; 9 cycles from STA long and BRA
	; -1 cycle from taking the BEQ branch
	; so let's waste 8 cycles
	TYA
	ORA (1,S), Y ; this is for Lui; 8 cycles in m=16

	; Container gfx
+	LDA #$24A2 : STA !POS_MEM_CONTAINER_GFX
	LDA #$0101 : STA !do_heart_lag

	; Container
	LDA.w SA1IRAM.CopyOf_7EF36C : AND #$00FF : LSR #3 : JSL hex_to_dec

	LDA.b SA1IRAM.SCRATCH+2 : ORA #$3C90 : STA.w SA1HUD+$000+!POS_CONTAINERS
	LDA.b SA1IRAM.SCRATCH+4 : ORA #$3C90 : STA.w SA1HUD+$002+!POS_CONTAINERS

	RTS

hud_draw_enemy_hp:
	; Assumes: I=16
	; Draw over Enemy Heart stuff in case theres no enemies
	LDA #!EMPTY : STA.w !POS_MEM_ENEMY_HEART_GFX
	STA.w SA1HUD+$000+!POS_ENEMY_HEARTS
	STA.w SA1HUD+$002+!POS_ENEMY_HEARTS
	STA.w SA1HUD+$004+!POS_ENEMY_HEARTS

	SEP #$30
	LDX #$FF

--	INX : CPX #$10 : BEQ .end
	LDA $0DD0, X : CMP #$09 : BEQ ++
	CMP #$0B : BNE --
++	BIT $0E60, X : BVC --

	LDA $0E50, X
	REP #$30
	AND #$00FF
	; Enemy HP should be in A
	JSL hex_to_dec : LDX.w #!POS_ENEMY_HEARTS : JSL draw3_white_aligned_left_lttp

	; Enemy Heart GFX
	LDA #$2CA0 : STA !POS_MEM_ENEMY_HEART_GFX

.end
--	RTS
