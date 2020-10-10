draw_coordinates_3:
	; x coordinate
	PHY
	TXA : TAY
	LDX.b SA1IRAM.Scratch+10
	AND #$000F : ORA #$3C10 : STA.w SA1HUD+$0704, X
	TYA : LSR #4 : AND #$000F : ORA #$3C10 : STA.w SA1HUD+$0702, X
	TYA : XBA ; swap to high byte
	AND #$000F : ORA #$3C10 : STA.w SA1HUD+$0700, X
	PLY

	; y coordinate
	TYA : AND #$000F : ORA #$3410 : STA.w SA1HUD+$070A, X
	TYA : LSR #4 : AND #$000F : ORA #$3410 : STA.w SA1HUD+$0708, X
	TYA : XBA ; swap to high byte
	AND #$000F : ORA #$3410 : STA.w SA1HUD+$0706, X
	RTL

draw_xy_single: ; byte in A, drawn HH:LL
	TAY ; cache A
	; low byte, Y coord
	LDX.b SA1IRAM.Scratch+10
	AND #$000F : ORA #$3410 : STA.w SA1HUD+$070A, X
	TYA : LSR #4 : AND #$000F : ORA #$3410 : STA.w SA1HUD+$0708, X

	TYA : XBA : TAY ; get old value back, change to high byte

	; high byte, X coord
	AND #$000F : ORA #$3C10 : STA.w SA1HUD+$0706, X
	TYA : LSR #4 : AND #$000F : ORA #$3C10 : STA.w SA1HUD+$0704, X

	RTL

draw_coordinates_2:
	; x coordinate
	PHY
	TXA : TAY
	LDX.b SA1IRAM.Scratch+10
	AND #$000F : ORA #$3C10 : STA.w SA1HUD+$0706, X
	TYA : LSR #4 : AND #$000F : ORA #$3C10 : STA.w SA1HUD+$0704, X
	PLY

	; y coordinate
	TYA : AND #$000F : ORA #$3410 : STA.w SA1HUD+$070A, X
	TYA : LSR #4 : AND #$000F : ORA #$3410 : STA.w SA1HUD+$0708, X
	RTL

draw3_red:
	; Clear leading 0's
	LDA #$207F : STA.w SA1HUD+$0700, X
	LDA #$207F : STA.w SA1HUD+$0702, X

	LDA.b SA1IRAM.SCRATCH+0 : BEQ .check_second_digit
	ORA #$3810 : STA.w SA1HUD+$0700, X : BRA .draw_second_digit

.check_second_digit
	LDA.b SA1IRAM.SCRATCH+2 : BEQ .draw_third_digit

.draw_second_digit
	LDA.b SA1IRAM.SCRATCH+2 : ORA #$3810 : STA.w SA1HUD+$0702, X

.draw_third_digit
	LDA.b SA1IRAM.SCRATCH+4 : ORA #$3810 : STA.w SA1HUD+$0704, X
	RTL

draw3_white:
	; Clear leading 0's
	LDA #$207F : STA.w SA1HUD+$0700, X
	LDA #$207F : STA.w SA1HUD+$0702, X

	LDA.b SA1IRAM.SCRATCH+0 : BEQ .check_second_digit
	ORA #$3C10 : STA.w SA1HUD+$0700, X : BRA .draw_second_digit

.check_second_digit
	LDA.b SA1IRAM.SCRATCH+2 : BEQ .draw_third_digit

.draw_second_digit
	LDA.b SA1IRAM.SCRATCH+2 : ORA #$3C10 : STA.w SA1HUD+$0702, X

.draw_third_digit
	LDA.b SA1IRAM.SCRATCH+4 : ORA #$3C10 : STA.w SA1HUD+$0704, X
	RTL

draw3_white_aligned_left:
	; Clear "leading" 0's
	LDA #$207F : STA.w SA1HUD+$0702, X
	LDA #$207F : STA.w SA1HUD+$0704, X

	LDA.b SA1IRAM.SCRATCH+0 : BEQ .draw_second_digit
	ORA #$3C10 : STA.w SA1HUD+$0700, X
	INX #2

.draw_second_digit
	LDA.b SA1IRAM.SCRATCH+2 : ORA #$3C10 : STA.w SA1HUD+$0700, X
	INX #2

.draw_third_digit
	LDA.b SA1IRAM.SCRATCH+4 : ORA #$3C10 : STA.w SA1HUD+$0700, X
	RTL

draw3_white_aligned_left_lttp:
	; Clear "leading" 0's
	LDA #$207F : STA.w SA1HUD+$0702, X
	LDA #$207F : STA.w SA1HUD+$0704, X

	LDA.b SA1IRAM.SCRATCH+0 : BEQ .draw_second_digit
	ORA #$3C90 : STA.w SA1HUD+$0700, X
	INX #2

.draw_second_digit
	LDA.b SA1IRAM.SCRATCH+2 : ORA #$3C90 : STA.w SA1HUD+$0700, X
	INX #2

.draw_third_digit
	LDA.b SA1IRAM.SCRATCH+4 : ORA #$3C90 : STA.w SA1HUD+$0700, X
	RTL


draw2_white:
	LDA.b SA1IRAM.SCRATCH+2 : ORA #$3C10 : STA.w SA1HUD+$0700, X
	LDA.b SA1IRAM.SCRATCH+4 : ORA #$3C10 : STA.w SA1HUD+$0702, X
	RTL


draw2_white_lttp:
	LDA.b SA1IRAM.SCRATCH+2 : ORA #$3C90 : STA.w SA1HUD+$0700, X
	LDA.b SA1IRAM.SCRATCH+4 : ORA #$3C90 : STA.w SA1HUD+$0702, X
	RTL

draw2_yellow:
	LDA.b SA1IRAM.SCRATCH+2 : ORA #$3410 : STA.w SA1HUD+$0706, X
	LDA.b SA1IRAM.SCRATCH+4 : ORA #$3410 : STA.w SA1HUD+$0708, X
	RTL


draw2_gray:
	LDA.b SA1IRAM.SCRATCH+2 : ORA #$2010 : STA.w SA1HUD+$070A, X
	LDA.b SA1IRAM.SCRATCH+4 : ORA #$2010 : STA.w SA1HUD+$070C, X
	RTL
