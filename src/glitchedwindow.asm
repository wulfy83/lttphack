function char(n) = $2150+n

!BROWN_PAL #= (0<<10)
!RED_PAL #= (1<<10)
!YELLOW_PAL #= (2<<10)
!BLUE_PAL #= (3<<10)
!GRAY_PAL #= (4<<10)
!REDYELLOW #= (5<<10)
!TEXT_PAL #= (6<<10)
!GREEN_PAL #= (7<<10)

!VFLIP #= (1<<15)
!HFLIP #= (1<<14)

!P3 = $2000
!SYNCED = char($10)|!BLUE_PAL
!DESYNC = char($11)|!RED_PAL
!HAMMER = char($12)|!BROWN_PAL

; $A0[2] room ID
; find a place to cache original room id that only works on proper transitions?

; $A2[2] previous room

; $E0[2], $E2[2], $E6[2], $E8[2] BG scrolling
; $0110[2] room id*3 only add if it seems to ever desync
; $7EC180[2] Initial camera scroll of room ; hook these to cache $A0?
; $7EC182[2] Initial camera scroll of room
; $7EC184[2] Initial link coord
; $7EC186[2] Initial link coord

; $0403 room data
; $040C dungeon ID
; $040E room header

; $0496 number of chests * 2

; $068E[2] WEST SOMARIA
; $0690[2] WEST SOMARIA

; $0716 scrolling? OW only?

; $7EC0000[5] stair destinations

; template for design planning
; 00000000001111111111222222222233
; 01234567890123456789012345678901
; ................................

UpdateGlitchedWindow:
	SEP #$30
	LDA.l !ram_superwatch
	AND.b #$03
	ASL : TAX
	JMP (.routines, X)

.routines
	dw NoSuperWatch
	dw UpdateAncillaWindow
	dw UpdateUWWindow
	dw NoSuperWatch

NoSuperWatch:
	LDA #$20

.set
	TRB.b SA1IRAM.HDMA_ASK
	RTS

UpdateUWWindow:
	LDA.l !ram_superwatch
	LSR : AND.b SA1IRAM.CopyOf_1B : LSR ; set or clear carry

	LDA #$20
	BCC NoSuperWatch_set
	LDX.b SA1IRAM.CopyOf_10 : CPX #$0E : BEQ NoSuperWatch_set
	CPX #$0C : BEQ NoSuperWatch_set
	TSB.b SA1IRAM.HDMA_ASK

	JSL ClearSWBuffer

	SEP #$10
print_coords:
	LDA.w #char(0)|!RED_PAL : STA !dg_buffer_r0+4 ; XY
	LDX #14
	LDA.b SA1IRAM.CopyOf_20 : JSR DrawHexSW_four_yellow
	LDA.b SA1IRAM.CopyOf_22 : JSR DrawHexSW_four_white

print_room_id:
	LDA.w #char(1)|!RED_PAL : STA !dg_buffer_r0+24 ; IDr
	INC : STA !dg_buffer_r0+26 ; INC for next char cheaply
	LDA.w #!HAMMER : STA !dg_buffer_r0+34 ; hammer

	LDX #26 : LDA.b SA1IRAM.CopyOf_A0 : JSR DrawHexSW_three_white

calc_correct_room_id:
	LDA.b SA1IRAM.CopyOf_21 : AND #$00FE : ASL #3 : STA.b SA1IRAM.SCRATCH+0
	LDA.b SA1IRAM.CopyOf_23 : AND #$00FE : LSR ; bit 0 is off, so it clears carry
	ADC.b SA1IRAM.SCRATCH+0 : STA.b SA1IRAM.SCRATCH+0

	LDX #34
	CMP.b SA1IRAM.CopyOf_A0 : BNE .roomdesync

.roomsynced
	JSR DrawHexSW_three_gray
	LDA.w #!SYNCED
	BRA .doneRoom

.roomdesync
	JSR DrawHexSW_three_red
	LDA.w #!DESYNC

.doneRoom
	STA !dg_buffer_r0+22

calc_room_flags:
	LDX #(2*(16-1))
	LDA.w SA1IRAM.CopyOf_0401 : ORA.w SA1IRAM.CopyOf_0408 : STA.b SA1IRAM.SCRATCH+0 ; not sure if I need $0400 at all?
	LDA.w SA1IRAM.CopyOf_0403 : STA.b SA1IRAM.SCRATCH+1
--	LDA.l .tiles, X : LSR.b SA1IRAM.SCRATCH+0 : BCS .flagSet
	ORA.w #!GRAY_PAL : BRA +

.flagSet
	ORA.l .palettes, X
+	STA !dg_buffer_r1+2+4, X
	DEX #2 : BPL --

	LDA.w #char($19)|!RED_PAL : STA !dg_buffer_r1+4

calc_quadrant:
	LDA.w #char($14)|!BLUE_PAL : STA !dg_buffer_r0+44
	LDA.w #!HAMMER : STA !dg_buffer_r0+48
	LDA.b SA1IRAM.CopyOf_A9 : LSR ; $A9 is 0 or 1
	BCS .east

.west
	BEQ .northwest ; $AA is 0 or 2, and will be the only bit remaining, no matter what

.southwest
	LDY #2
	LDA.w #char(5+2)|!RED_PAL
	BRA .doQuadrant

.northwest
	LDY #3
	LDA.w #char(5+3)|!RED_PAL
	BRA .doQuadrant

.east
	BEQ .northeast ; $AA is 0 or 2, and will be the only bit remaining, no matter what

.southeast
	LDY #1
	LDA.w #char(5+1)|!RED_PAL
	BRA .doQuadrant

.northeast
	LDY #0
	LDA.w #char(5+0)|!RED_PAL
;	BRA .doQuadrant


.doQuadrant
	STY.b SA1IRAM.SCRATCH+0
	STA !dg_buffer_r0+46

calc_correct_quadrant:
	LDA #$0100 ; checking the same bit on both coordinates

	BIT.b SA1IRAM.CopyOf_22 : BNE .east

.west
	BIT.b SA1IRAM.CopyOf_20 : BEQ .northwest

	; using the gray pal means we only need to ORA if desynched
	; and can leave it alone otherwise
.southwest
	LDY #2
	LDA.w #char(5+2)|!GRAY_PAL
	BRA .doQuadrant

.northwest
	LDY #3
	LDA.w #char(5+3)|!GRAY_PAL
	BRA .doQuadrant

.east
	BIT.b SA1IRAM.CopyOf_20 : BEQ .northeast

.southeast
	LDY #1
	LDA.w #char(5+1)|!GRAY_PAL
	BRA .doQuadrant

.northeast
	LDY #0
	LDA.w #char(5+0)|!GRAY_PAL

.doQuadrant
	CPY.b SA1IRAM.SCRATCH+0 : BEQ .quadrantsSynced
	ORA.w #!TEXT_PAL
	STA !dg_buffer_r0+50
	LDA.w #!DESYNC : BRA ++

.quadrantsSynced
	STA !dg_buffer_r0+50
	LDA.w #!SYNCED
++	STA !dg_buffer_r0+52

draw_camera:
	LDA.w #char($13)|!GRAY_PAL ; camera icon
	STA !dg_buffer_r2+4
	STA !dg_buffer_r3+4
	LDX.b #(64+64)+6 : LDA.b SA1IRAM.CopyOf_E2 : JSR DrawHexSW_four_white
	LDX.b #(64+64+64)+6 : LDA.b SA1IRAM.CopyOf_E8 : JSR DrawHexSW_four_yellow

	LDX.b SA1IRAM.CopyOf_A6
	LDA.w SA1IRAM.CopyOf_0608, X : STA.b SA1IRAM.SCRATCH+0 ; cache X camera for desync check
	LDA.w SA1IRAM.CopyOf_060C, X : STA.b SA1IRAM.SCRATCH+2
	CPX #$02 : BEQ .XSet2

.XSet1
	LDA.w #char(9)|!RED_PAL ; labels
	STA !dg_buffer_r2+16
	INC : STA !dg_buffer_r2+26

	LDA.w #char(9)|!GRAY_PAL
	STA !dg_buffer_r2+36
	INC : STA !dg_buffer_r2+46

	LDX.b #(64+64)+18 : LDA.w SA1IRAM.CopyOf_0608 : JSR DrawHexSW_four_white
	LDX.b #(64+64)+28 : LDA.w SA1IRAM.CopyOf_060C : JSR DrawHexSW_four_white
	LDX.b #(64+64)+38 : LDA.w SA1IRAM.CopyOf_060A : JSR DrawHexSW_four_gray
	LDX.b #(64+64)+48 : LDA.w SA1IRAM.CopyOf_060E : JSR DrawHexSW_four_gray
	BRA .checkXSync

.XSet2
	LDA.w #char(9)|!GRAY_PAL ; labels
	STA !dg_buffer_r2+16
	INC : STA !dg_buffer_r2+26

	LDA.w #char(9)|!RED_PAL
	STA !dg_buffer_r2+36
	INC : STA !dg_buffer_r2+46

	LDX.b #(64+64)+18 : LDA.w SA1IRAM.CopyOf_0608 : JSR DrawHexSW_four_gray
	LDX.b #(64+64)+28 : LDA.w SA1IRAM.CopyOf_060C : JSR DrawHexSW_four_gray
	LDX.b #(64+64)+38 : LDA.w SA1IRAM.CopyOf_060A : JSR DrawHexSW_four_white
	LDX.b #(64+64)+48 : LDA.w SA1IRAM.CopyOf_060E : JSR DrawHexSW_four_white

.checkXSync
	LDA.b SA1IRAM.CopyOf_E2 : CMP.b SA1IRAM.SCRATCH+0 : BCC .xDesynced
	; decrement so that equal values result in a clear carry
	DEC : CMP.b SA1IRAM.SCRATCH+2 : BCS .xDesynced

.xProbablyFine
	LDA.w #!SYNCED
	BRA .drawXSync

.xDesynced
	LDA.w #!DESYNC 

.drawXSync
	STA !dg_buffer_r2+14


	LDX.b SA1IRAM.CopyOf_A7
	LDA.w SA1IRAM.CopyOf_0600, X : STA.b SA1IRAM.SCRATCH+0 ; cache Y camera for desync check
	LDA.w SA1IRAM.CopyOf_0604, X : STA.b SA1IRAM.SCRATCH+2
	CPX #$02 : BEQ .YSet2

.YSet1
	LDA.w #char(11)|!REDYELLOW ; labels
	STA !dg_buffer_r3+16
	INC : STA !dg_buffer_r3+26

	LDA.w #char(11)|!GRAY_PAL
	STA !dg_buffer_r3+36
	INC : STA !dg_buffer_r3+46

	LDX.b #(64+64+64)+18 : LDA.w SA1IRAM.CopyOf_0600 : JSR DrawHexSW_four_yellow
	LDX.b #(64+64+64)+28 : LDA.w SA1IRAM.CopyOf_0604 : JSR DrawHexSW_four_yellow
	LDX.b #(64+64+64)+38 : LDA.w SA1IRAM.CopyOf_0602 : JSR DrawHexSW_four_gray
	LDX.b #(64+64+64)+48 : LDA.w SA1IRAM.CopyOf_0606 : JSR DrawHexSW_four_gray
	BRA .checkYSync

.YSet2
	LDA.w #char(11)|!GRAY_PAL ; labels
	STA !dg_buffer_r3+16
	INC : STA !dg_buffer_r3+26

	LDA.w #char(11)|!REDYELLOW
	STA !dg_buffer_r3+36
	INC : STA !dg_buffer_r3+46

	LDX.b #(64+64+64)+18 : LDA.w SA1IRAM.CopyOf_0600 : JSR DrawHexSW_four_gray
	LDX.b #(64+64+64)+28 : LDA.w SA1IRAM.CopyOf_0604 : JSR DrawHexSW_four_gray
	LDX.b #(64+64+64)+38 : LDA.w SA1IRAM.CopyOf_0602 : JSR DrawHexSW_four_yellow
	LDX.b #(64+64+64)+48 : LDA.w SA1IRAM.CopyOf_0606 : JSR DrawHexSW_four_yellow

.checkYSync
	LDA.b SA1IRAM.CopyOf_E8 : CMP.b SA1IRAM.SCRATCH+0 : BCC .yDesynced
	; decrement so that equal values result in a clear carry
	DEC : CMP.b SA1IRAM.SCRATCH+2 : BCS .yDesynced

.yProbablyFine
	LDA.w #!SYNCED
	BRA .drawYSync

.yDesynced
	LDA.w #!DESYNC 

.drawYSync
	STA !dg_buffer_r3+14

;OverlayPTR = $04E9A0
;!NON_VANILLA = char($16)|!YELLOW_PAL
;!CRITICAL = char($17)|!RED_PAL
;
;draw_overlay:
;	LDA.w #char($18)|!YELLOW_PAL : STA !dg_buffer_r1+40
;
;	LDA $BA : BNE .preloaded
;
;	REP #$10
;	LDA $04BA : ASL : CLC : ADC $04BA : TAX
;	LDA.l OverlayPTR+1, X : STA.b SA1IRAM.SCRATCH+1
;	LDA.l OverlayPTR+0, X : STA.b SA1IRAM.SCRATCH+0
;	SEP #$10
;	LDA.w #char($1C)|!RED_PAL ; from ROM
;	BRA .draw
;
;.preloaded
;	LDA $B8 : STA.b SA1IRAM.SCRATCH+1
;	LDA $B7 : STA.b SA1IRAM.SCRATCH+0
;	LDA.w #char($1B)|!RED_PAL ; from RAM
;
;.draw
;	STA !dg_buffer_r1+42
;	;REP #$10
;	LDX #(64+44) : LDA.b SA1IRAM.SCRATCH+2 : JSR DrawHexSW_two_white ; this doesn't change X flag
;	LDX #(64+48) : LDA.b SA1IRAM.SCRATCH+0 : JSR DrawHexSW_four_white ; this exits i=10 - might not need
;
;	LDA.b SA1IRAM.SCRATCH+1 : AND #$FF00
;	CMP #$7000 : BCC .notSRAM ; check <$70 first, to avoid work ram checks
;	CMP #$7E00 : BEQ .workRAM
;	CMP #$7F00 : BEQ .workRAM
;	CMP #$7000 : BCS .notSRAM
;	LDA.w #!CRITICAL
;	BRA .drawWarning
;
;.notSRAM
;	LDA.b SA1IRAM.SCRATCH+1 : AND #$00FF ; see what page it's on
;	CMP #$0080 : BCC .workRAM ; if it's less than page $80, we're not in ROM
;
;	LDA.b SA1IRAM.SCRATCH+1 : AND #$3FFF ; account for mirroring of ROM
;	CMP #$2080 : BCC .notHacked ; before bank20 and we're okay
;	CMP.w #(((EndOfPracticeROM>>8)&$FF00)+$0100) : BCS .notHacked ; the last bank we *don't* use
;	LDA.w #!NON_VANILLA : BRA .drawWarning
;
;; this assumes before $8000 is volatile in all banks
;; while some banks don't mirror work ram or registers
;; I think that just means the lower half is open bus
;; in which case it's as volatile as you can get
;.workRAM 
;	LDA.w #!CRITICAL : BRA .drawWarning
;
;.notHacked
;	LDA.w #!EMPTY
;
;.drawWarning
;	STA !dg_buffer_r1+56

trigger_update:
	SEP #$20
	RTS

!CHEST_TILE = char($15)
!QUAD = char($14)
!DOOR_TILE = char($1A)

calc_room_flags_tiles:
	dw $20A0 ; heart
	dw $2071 ; key
	dw $2071 ; key
	dw !CHEST_TILE, !CHEST_TILE, !CHEST_TILE, !CHEST_TILE, !CHEST_TILE
	dw !DOOR_TILE, !DOOR_TILE, !DOOR_TILE, !DOOR_TILE
	dw !QUAD|!HFLIP, !QUAD, !QUAD|!HFLIP|!VFLIP, !QUAD|!VFLIP

	; TODO: for quadrants, include the flipping in tile
	; also make them go RYGB,
calc_room_flags_palettes:
	dw !RED_PAL, !YELLOW_PAL, !YELLOW_PAL
	dw !RED_PAL, !RED_PAL, !RED_PAL, !RED_PAL, !RED_PAL
	dw !BROWN_PAL, !BROWN_PAL, !BROWN_PAL, !BROWN_PAL
	dw !BLUE_PAL, !RED_PAL, !GREEN_PAL, !YELLOW_PAL


DrawHexSW:
.four
..white
	LDY.b #(!P3|!RED_PAL)>>8
	BRA ..set

..yellow
	LDY.b #(!P3|!REDYELLOW)>>8
	BRA ..set

..gray
	LDY.b #(!P3|!GRAY_PAL)>>8
	BRA ..set

..red
	LDY.b #(!P3|!TEXT_PAL)>>8
	BRA ..set

..set
	STY.w SA1IRAM.SCRATCH+11
	LDY.b #$10
	STY.w SA1IRAM.SCRATCH+10
	LDY.b #4
	BRA .draw_n_digits

.three
..white
	LDY.b #(!P3|!RED_PAL)>>8
	BRA ..set

..yellow
	LDY.b #(!P3|!REDYELLOW)>>8
	BRA ..set

..gray
	LDY.b #(!P3|!GRAY_PAL)>>8
	BRA ..set

..red
	LDY.b #(!P3|!TEXT_PAL)>>8
	BRA ..set

..set
	STY.w SA1IRAM.SCRATCH+11
	LDY.b #$10
	STY.w SA1IRAM.SCRATCH+10
	LDY.b #3
	BRA .draw_n_digits

.two
..white
	LDY.b #(!P3|!RED_PAL)>>8
	BRA ..set

..yellow
	LDY.b #(!P3|!REDYELLOW)>>8
	BRA ..set

..gray
	LDY.b #(!P3|!GRAY_PAL)>>8
	BRA ..set

..red
	LDY.b #(!P3|!TEXT_PAL)>>8
	BRA ..set

..set
	STY.w SA1IRAM.SCRATCH+11
	LDY.b #$10
	STY.w SA1IRAM.SCRATCH+10
	LDY.b #3
	BRA .draw_n_digits

.next_digit
	LSR
	LSR
	LSR
	LSR

.draw_n_digits
	PHA ; remember coordinates
	AND.w #$000F ; get digit
	ORA.b SA1IRAM.SCRATCH+10 ; add in color
	STA.w !dg_dma_buffer+6, X
	PLA ; recover value
	DEX
	DEX
	DEY
	BNE .next_digit
	RTS
