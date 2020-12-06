UpdateHoverCounter:
	PHA : PHP
	REP #$20
	LDA $F2
	AND #$0080
	BEQ .dash_not_held

	; dash held
	LDA #$0001
	PHA
	LDA !ram_hover_dashing
	BNE .reset_counter

	LDA !ram_hover_dash_held_last_frame
	BNE .decrement_countdown

	; just started holding dash
	LDA #$0000
	STA !ram_hover_dashing
	LDA #$001D
	BRA .store_countdown

	.decrement_countdown
	LDA !ram_hover_dash_countdown
	DEC

	.store_countdown
	STA !ram_hover_dash_countdown
	BNE .increment_counter

	; countdown reached 0, start dashing
	LDA #$0001
	STA !ram_hover_dashing
	BRA .reset_counter

	.dash_not_held
	LDA #$0000
	PHA
	STA !ram_hover_dash_countdown
	STA !ram_hover_dashing
	LDA !ram_hover_dash_held_last_frame
	BNE .increment_counter

	.reset_counter
	LDA #$0000
	BRA .done
	.increment_counter
	LDA !ram_hover_counter
	INC
	.done
	STA !ram_hover_counter
	PLA
	STA !ram_hover_dash_held_last_frame
	PLP : PLA
	RTL
