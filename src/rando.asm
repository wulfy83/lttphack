QuickSwap:
	; We perform all other checks only if we are pushing L or R in order to have minimal
	; perf impact, since this runs every frame
	LDA.b $F6 : AND #$30 : BEQ .done

	XBA ; stash away the value for after the checks.

	LDA.w $0202 : BEQ .done ; Skip everything if we don't have any items

	PHX
	XBA ; restore the stashed value
	CMP.b #$30 : BNE +
		; If pressing both L and R this frame, then go directly to the special swap code
		LDX.w $0202 : BRA .special_swap
	+
	BIT #$10 : BEQ + ; Only pressed R
		JSR.w QuickSwap_R
		LDA.b $F2 : BIT #$20 : BNE .special_swap ; Still holding L from a previous frame
		BRA .store
	+
	; Only pressed L
	JSR.w QuickSwap_L
	LDA.b $F2 : BIT #$10 : BNE .special_swap ; Still holding R from a previous frame
	BRA .store

	.special_swap
	CPX.b #$02 : BEQ + ; boomerang
	CPX.b #$01 : BEQ + ; bow
	CPX.b #$05 : BEQ + ; powder
	CPX.b #$0D : BEQ + ; flute
	BRA .store
	+ STX $0202 : JSL QuickSwap_Special

	.store
	LDA.b #$20 : STA.w $012F
	STX $0202

	HUD_RefreshIconLong = $0DDB7F
	JSL HUD_RefreshIconLong
	PLX

	.done
	LDA.b $F6 : AND.b #$40 ; what we wrote over
RTL

QuickSwap_R:
	LDA.w $0202 : TAX
	-
		CPX.b #$0F : BNE + ; incrementing into bottle
			LDX.b #$00 : BRA ++
		+ CPX.b #$10 : BNE + ; incrementing bottle
			LDA.l $7EF34F : TAX
			-- : ++
				CPX.b #$04 : BEQ .noMoreBottles
				INX
				LDA.l $7EF35B,X : BEQ --
			TXA : STA.l $7EF34F
			LDX #$10
			RTS
			.noMoreBottles
			LDX #$11
			BRA .nextItem
		+ CPX.b #$14 : BNE + : LDX.b #$00 ; will wrap around to 1
		+ INX
	.nextItem
	LDA $7EF33F, X : BEQ -
RTS

QuickSwap_L:
	LDA.w $0202 : TAX
	-
		CPX.b #$11 : BNE + ; decrementing into bottle
			LDX.b #$05 : BRA ++
		+ CPX.b #$10 : BNE +	; decrementing bottle
			LDA.l $7EF34F : TAX
			-- : ++
				CPX.b #$01 : BEQ .noMoreBottles
				DEX
				LDA.l $7EF35B,X : BEQ --
			TXA : STA.l $7EF34F
			LDX.b #$10
			RTS
			.noMoreBottles
			LDX.b #$0F : BRA .nextItem
		+ CPX.b #$01 : BNE + : LDX.b #$15 ; will wrap around to $14
		+ DEX
	.nextItem
	LDA $7EF33F, X : BEQ -
RTS

QuickSwap_Special:
	; Note: used as entry point by quickswap code. Must preserve X.
	LDA.b #$10 : STA $0207
	LDA $0202 ; check selected item
	CMP #$02 : BNE + ; boomerang
		LDA $7EF341 : EOR #$03 : STA $7EF341 ; swap blue & red boomerang
		LDA.b #$20 : STA $012F ; menu select sound
		BRA .done
	+ CMP #$01 : BNE + ; bow
		PHX : LDX.b #$00 ; scan ancilla table for arrows
			-- : CPX.b #$0A : BCS ++
				LDA $0C4A, X : CMP.b #$09 : BNE +++
					PLX : BRA .error ; found an arrow, don't allow the swap
				+++
			INX : BRA -- : ++
		PLX
		LDA $7EF340 : DEC : EOR #$02 : INC : STA $7EF340 ; swap bows
		LDA.b #$20 : STA $012F ; menu select sound
		BRA .done
	+ CMP #$05 : BNE + ; powder
		LDA $7EF344 : EOR #$03 : STA $7EF344 ; swap mushroom & magic powder
		LDA.b #$20 : STA $012F ; menu select sound
		BRA .done
	+ CMP #$0D : BNE + ; flute
		LDA $037A :	CMP #$01 : BEQ .error ; inside a shovel animation, make error sound
		LDA $7EF34C : CMP #01 : BNE .toShovel ; not shovel

		LDA #$03 ; set real flute
		BRA .fluteSuccess
		.toShovel
		LDA #$01 ; set shovel
		.fluteSuccess
		STA $7EF34C ; store set item
		LDA.b #$20 : STA $012F ; menu select sound
		BRA .done
	+
	.done
RTL
	.error
	LDA.b #$3C : STA $012E ; error sound
RTL

pushpc
org $0287FB ; <- 107FB - Bank02.asm:1526 (LDA $F6 : AND.b #$40 : BEQ .dontActivateMap)
JSL.l QuickSwap
org $02A451 ; <- 12451 - Bank02.asm:6283 (LDA $F6 : AND.b #$40 : BEQ .xButtonNotDown)
JSL.l QuickSwap
pullpc

; Remove item received text
org $08C301
dw $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF
dw $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF
dw $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF
dw $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF
dw $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF
dw $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF
dw $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF
dw $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF
dw $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF
dw $FFFF, $FFFF, $FFFF, $FFFF
org $08C3A2
dw $FFFF, $FFFF, $FFFF, $FFFF

; Hammer can damage Ganon
org $06F2ED
CMP.b #$D8
