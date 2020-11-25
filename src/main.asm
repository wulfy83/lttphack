math pri on

sa1rom

!VERSION ?= "ALEPH 1"

incsrc defines.asm
incsrc hexedits.asm
incsrc registers.asm

org $208000
incsrc sa1hooks.asm
incsrc gamemode.asm
incsrc nmi.asm
incsrc timers.asm
incsrc hudextras.asm
incsrc hudextras_uw.asm
incsrc hudextras_ancilla.asm

org $228000
incsrc tiles.asm

org $238000
incsrc init.asm
incsrc rng.asm
incsrc misc.asm

org $248000
incsrc custom_menu.asm
print "Custom menu size: ", pc

org $268000
incsrc presets.asm

org $288000
incsrc music.asm

org $298000
incsrc movie.asm

; ---- data ----

org $308000
incsrc preset_data_nmg.asm

org $318000
incsrc preset_data_hundo.asm

org $328000
incsrc preset_data_lowleg.asm

org $338000
incsrc preset_data_ad.asm

org $348000
incsrc preset_data_anyrmg.asm
incsrc preset_data_ad2020.asm

org $358000
incsrc preset_data_lownmg.asm

;========================================================================
; LEAVE THIS HERE
; it's needed for calculating when certain data comes from a possibly
; non-vanilla source, which requires knowing the last bank we write to
;========================================================================
EndOfPracticeROM:

; pad rom to 2mb
org $3FFFFF
db $FF
