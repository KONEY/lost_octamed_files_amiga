;*** WWW.KONEY.ORG *******
;*** MiniStartup by Photon ***
	INCDIR	"NAS:AMIGA/CODE/lost_octamed_files_amiga/"
	SECTION	"Code",CODE
	INCLUDE	"custom-registers.i"
	INCLUDE	"PhotonsMiniWrapper1.04!.S"
;********** Constants **********
wd		EQU 368		; screen width, height, depth
hg		EQU 230
bpls		EQU 5		; handy values:
bwpl		EQU wd/16*2	; byte-width of 1 bitplane line (46)
bwid		EQU bpls*bwpl	; byte-width of 1 pixel line (all bpls)
TXT_FRMSKIP 	EQU 3
BLOCK_SKIP	EQU 2
SKIP_IDLE_TIME	EQU 30*6
;*************
;CLR.W	$100		; DEBUG | w 0 100 2
;********** Demo **********	; Demo-specific non-startup code below.
Demo:				; a4=VBR, a6=Custom Registers Base addr
	;*--- init ---*
	MOVE.L	#VBint,$6C(A4)
	;MOVE.W	#%1110000000100000,INTENA
	;** SOMETHING INSIDE HERE IS NEEDED TO MAKE MOD PLAY! **
	MOVE.W	#%1110000000000000,INTENA	; Master and lev6	; NO COPPER-IRQ!
	MOVE.W	#%1000011111100000,DMACON
	;*--- clear screens ---*
	;LEA	SCREEN1,A1
	;BSR.W	ClearScreen
	;LEA	SCREEN2,A1
	;BSR.W	ClearScreen
	;BSR	WaitBlitter
	;*--- start copper ---*
	LEA	SCREEN1,A0

	MOVEQ	#bwpl,D0
	LEA	COPPER1\.BplPtrs+2,A1
	MOVEQ	#bpls-1,D1
	BSR.W	PokePtrs

	; #### CPU INTENSIVE TASKS BEFORE STARTING MUSIC
	MOVE.W	#0,D3		; PARAMETERS
	LEA	SPRT_A\.DATA,A4	; PARS
	BSR.W	__POPULATESPRITE
	MOVE.L	#2,D3		; PARAMETERS
	LEA	SPRT_N\.DATA,A4	; PARS
	BSR.W	__POPULATESPRITE
	BSR.W	__POINT_SPRITES	; #### Point sprites
	; #### CPU INTENSIVE TASKS BEFORE STARTING MUSIC

	MOVE.B	$DFF00A,MOUSE_Y
	MOVE.B	$DFF00B,MOUSE_X
	; in photon's wrapper comment:;move.w d2,$9a(a6) ;INTENA

	JSR	_startmusic

	MOVE.L	#COPPER1,COP1LC		; COP1LCH
;********************  main loop  ********************
MainLoop:
	move.w	#$12c,d0		;No buffering, so wait until raster
	bsr.w	WaitRaster	;is below the Display Window.
	;*--- swap buffers ---*
	movem.l	DrawBuffer(PC),a2-a3
	exg	a2,a3
	movem.l	a2-a3,DrawBuffer	;draw into a2, show a3
	;*--- show one... ---*
	move.l	a3,a0
	move.l	#bwpl*hg,d0
	lea	COPPER1\.BplPtrs+2,a1
	moveq	#bpls-1,d1
	bsr.w	PokePtrs
	;*--- ...draw into the other(a2) ---*
	move.l	a2,a1
	;MOVE.L	#TR808,DrawBuffer
	; do stuff here :)
	BSR.W	__SET_SEQUENCER_LEDS
	BSR.W	__FILLANDSCROLLTXT

	;MOVE.W	MED_STEPSEQ_POS,D3 	; PARAMETERS
	;LEA	SPRT_1\.DATA,A4	; PARS
	;BSR.W	__POPULATESPRITE

	; # KEYBLOCK CHANGES #
	TST.W	COUNTDOWN
	BNE.W	.Skip

	TST.W	MED_BLOCK_LINE
	BNE.S	.Skip

	;CLR.W	$100			; DEBUG | w 0 100 2
	MOVE.L	KEYBLOCKS_INDEX,D3
	ADD.W	#BLOCK_SKIP,D3
	LEA	KEYBLOCKS,A2
	MOVE.W	(A2,D3.W),D1
	MOVE.W	MED_SONG_POS,D2
	CMP.W	D1,D2
	BNE.S	.Skip

	MOVE.L	D3,KEYBLOCKS_INDEX	; update index
	MOVE.W	#SKIP_IDLE_TIME,COUNTDOWN
	MOVE.L	#SPRT_N,ACTUALSPRITE	; sprite 0
	BSR.W	__POINT_SPRITES		; #### Point sprites
	LEA	SPRT_A\.DATA,A4		; PARS
	BSR.W	__POPULATESPRITE
	;MOVE.W	#$F0F,$DFF180		; show rastertime left down to $12c
	.Skip:

	TST.W	COUNTDOWN
	BEQ.S	.dontDecrease
	SUB.W	#1,COUNTDOWN
	.dontDecrease:

	MOVE.W	COUNTDOWN,D5
	CMP.W	#1,D5
	BNE.S	.dontReset
	MOVE.W	#0,COUNTDOWN
	MOVE.L	#SPRT_K,ACTUALSPRITE	; sprite 0

	MOVE.L	#SPRT_A,A1	; indirizzo sprite
	MOVE.W	#$FF,D0
	MOVE.W	#$FF,D1
	MOVEQ	#16,D2		; altezza sprite
	BSR.W	UniMuoviSprite	; chiama la routine universale

	BSR.W	__POINT_SPRITES	; #### Point sprites
	MOVE.L	KEYBLOCKS_INDEX,D3
	ADD.W	#BLOCK_SKIP,D3
	LEA	SPRT_N\.DATA,A4	; PARS
	BSR.W	__POPULATESPRITE
	.dontReset:

	BSR.W	LeggiMouse	; questa legge il mouse
	MOVE.W	SPRITE_Y(PC),D0	; prepara i parametri per la routine
	MOVE.W	SPRITE_X(PC),D1	; universale
	MOVE.L	ACTUALSPRITE,A1	; indirizzo sprite
	MOVEQ	#16,D2		; altezza sprite
	BSR.W	UniMuoviSprite	; chiama la routine universale

	;*--- main loop end ---*
	; # CODE FOR BUTTON PRESS ##
	TST.W	COUNTDOWN
	BNE.S	.SkipButtonActions
	BTST	#6,$BFE001
	BNE.S	.SkipButtonActions
	TST.W	LMBUTTON_STATUS
	BNE.S	.SkipButtonActions
	MOVE.W	#1,LMBUTTON_STATUS
	;MOVE.W	#$F00,$DFF180	; show rastertime left down to $12c
	; ## SONG POSITION ##
	MOVE.L	KEYBLOCKS_INDEX,D3
	CMPI.L	#14*2,D3		; CHECK IF ITS LAST SONG
	BGE.S	.SkipButtonActions	; SKIP MORE SKIPS :)
	ADD.W	#BLOCK_SKIP,D3
	LEA	KEYBLOCKS,A2
	MOVE.W	(A2,D3.W),MED_SONG_POS
	; ## SONG POSITION ##
	MOVE.L	#SPRT_A,ACTUALSPRITE	; sprite 0
	BSR.W	__POINT_SPRITES	; #### Point sprites

	LEA	SPRT_N\.DATA,A4	; PARS
	BSR.W	__POPULATESPRITE

	.SkipButtonActions:
	BTST	#6,$BFE001
	BEQ.S	.DontResetStatus
	MOVE.W	#0,LMBUTTON_STATUS
	.DontResetStatus:

	.QUITCODE:
	BTST	#2,$DFF016	; POTINP - RMB pressed?
	BNE.W	MainLoop		; then loop
	.quit:
	;*--- exit ---*
	; ---  quit MED code  ---
	MOVEM.L	D0-A6,-(SP)
	JSR	_endmusic
	MOVEM.L	(SP)+,D0-A6
	RTS

;********** Demo Routines **********
PokePtrs:				; Generic, poke ptrs into copper list
	.bpll:	
	move.l	a0,d2
	swap	d2
	move.w	d2,(a1)		; high word of address
	move.w	a0,4(a1)		; low word of address
	addq.w	#8,a1		; skip two copper instructions
	add.l	d0,a0		; next ptr
	dbf	d1,.bpll
	rts
ClearScreen:			; a1=screen destination address to clear
	bsr	WaitBlitter
	clr.w	BLTDMOD		; destination modulo
	move.l	#$01000000,BLTCON0	; set operation type in BLTCON0/1
	move.l	a1,BLTDPTH	; destination address
	move.l	#hg*bpls*64+bwpl/2,BLTSIZE	;blitter operation size
	rts
VBint:				; Blank template VERTB interrupt
	btst	#5,$DFF01F	; check if it's our vertb int.
	beq.s	.notvb
	move.w	#$20,$DFF09C	; poll irq bit
	move.w	#$20,$DFF09C	; KONEY REFACTOR
	.notvb:	
	rte

LeggiMouse:
	MOVE.B	$DFF00A,D1	; JOY0DAT posizione verticale mouse
	MOVE.B	D1,D0		; copia in d0
	SUB.B	MOUSE_Y(PC),D0	; sottrai vecchia posizione mouse
	BEQ.S	.no_vert		; se la differenza = 0, il mouse e` fermo
	EXT.W	D0		; trasforma il byte in word
	ADD.W	D0,SPRITE_Y	; modifica posizione sprite
	.no_vert:
	MOVE.B	D1,MOUSE_Y	; salva posizione mouse per la prossima volta

	MOVE.W	SPRITE_Y(PC),D0	; CHECK MOUSE AREA BOUNDARIES
	CMPI.W	#$FF00,D0
	BLO.S	.Y_T_ok
	MOVE.W	#0,SPRITE_Y
	BRA.S	.Y_B_ok
	.Y_T_ok:

	CMPI.W	#hg-18,D0
	BLO.S	.Y_B_ok
	MOVE.W	#hg-18,SPRITE_Y
	.Y_B_ok:

	MOVE.B	$DFF00B,D1	; posizione orizzontale mouse
	MOVE.B	D1,D0		; copia in d0
	SUB.B	MOUSE_X(PC),D0	; sottrai vecchia posizione
	BEQ.S	.no_oriz		; se la differenza = 0, il mouse e` fermo
	EXT.W	D0		; trasforma il byte in word
	ADD.W	D0,SPRITE_X	; modifica pos. sprite
	.no_oriz:
	MOVE.B	D1,MOUSE_X	; salva posizione mouse per la prossima volta

	MOVE.W	SPRITE_X(PC),D0	; CHECK MOUSE AREA BOUNDARIES
	CMPI.W	#$FF00,D0
	BLO.S	.X_T_ok
	MOVE.W	#0,SPRITE_X
	BRA.S	.X_B_ok
	.X_T_ok:

	CMPI.W	#wd-15,D0
	BLO.S	.X_B_ok
	MOVE.W	#wd-15,SPRITE_X
	.X_B_ok:
	RTS

UniMuoviSprite:
	; posizionamento verticale
	ADD.W	#$2c,d0		; aggiungi l'offset dell'inizio dello schermo
				; a1 contiene l'indirizzo dello sprite
	MOVE.b	d0,(a1)		; copia il byte in VSTART
	btst.l	#8,d0
	beq.s	.NonVSTARTSET
	bset.b	#2,3(a1)		; Setta il bit 8 di VSTART (numero > $FF)
	bra.s	.ToVSTOP
	.NonVSTARTSET:
	bclr.b	#2,3(a1)		; Azzera il bit 8 di VSTART (numero < $FF)
	.ToVSTOP:
	ADD.w	D2,D0		; Aggiungi l'altezza dello sprite per
				; determinare la posizione finale (VSTOP)
	move.b	d0,2(a1)		; Muovi il valore giusto in VSTOP
	btst.l	#8,d0
	beq.s	.NonVSTOPSET
	bset.b	#1,3(a1)		; Setta il bit 8 di VSTOP (numero > $FF)
	bra.w	.VstopFIN
	.NonVSTOPSET:
	bclr.b	#1,3(a1)		; Azzera il bit 8 di VSTOP (numero < $FF)
	.VstopFIN:
	; posizionamento orizzontale
	add.w	#128,D1		; 128 - per centrare lo sprite.
	btst	#0,D1		; bit basso della coordinata X azzerato?
	beq.s	.BitBassoZERO
	bset	#0,3(a1)		; Settiamo il bit basso di HSTART
	bra.s	.PlaceCoords
	.BitBassoZERO:
	bclr	#0,3(a1)		; Azzeriamo il bit basso di HSTART
	.PlaceCoords:
	lsr.w	#1,D1		; SHIFTIAMO, ossia spostiamo di 1 bit a destra
				; il valore di HSTART, per "trasformarlo" nel
				; valore fa porre nel byte HSTART, senza cioe'
				; il bit basso.
	move.b	D1,1(a1)		; Poniamo il valore XX nel byte HSTART
	RTS

__SET_SEQUENCER_LEDS:
	; ## SEQUENCER LEDS ##
	MOVE.W	MED_STEPSEQ_POS,D0
	ANDI.W	#15,D0
	MOVE.W	D0,MED_STEPSEQ_POS
	LEA	SEQ_POS_ON,A0
	MOVE.B	(A0,D0.W),LED_ON\.HPOS
	LEA	SEQ_POS_OFF,A0
	MOVE.B	(A0,D0.W),LED_OFF\.HPOS
	;LEA	SEQ_VPOS_ON,A0
	;MOVE.B	(A0,D0.W),LED_ON\.VPOS
	;LEA	SEQ_VPOS_OFF,A0
	;MOVE.B	(A0,D0.W),LED_OFF\.VPOS
	;LEA	SEQ_POS_BIT,A0
	;MOVE.B	(A0,D0.W),LED_ON\.CTRL
	;MOVE.B	(A0,D0.W),LED_OFF\.CTRL
	RTS

__FILLANDSCROLLTXT:
	MOVE.W	FRAMESINDEX,D7
	CMPI.W	#TXT_FRMSKIP,D7	; TXT_FRMSKIP
	BNE.W	.SKIP
	LEA	TR808_END,A4
	LEA	FONT,A5
	LEA	TEXT,A3
	SUB.W	#(bwpl*9)-1,A4	; POSITIONING
	ADD.W	TEXTINDEX,A3
	CMP.L	#_TEXT-1,A3	; Siamo arrivati all'ultima word della TAB?
	BNE.S	.PROCEED
	MOVE.W	#0,TEXTINDEX	; Riparti a puntare dalla prima word
	LEA	TEXT,A3		; FIX FOR GLITCH (I KNOW IT'S FUN... :)
	.PROCEED:
	MOVE.B	(A3),D2		; Prossimo carattere in d2
	SUBI.B	#$20,D2		; TOGLI 32 AL VALORE ASCII DEL CARATTERE, IN
	MULU.W	#8,D2		; MOLTIPLICA PER 8 IL NUMERO PRECEDENTE,
	ADD.W	D2,A5
	MOVEQ	#0,D6		; RESET D6
	MOVE.B	#8-1,D6
	.LOOP:
	ADD.W	#bwpl-2,A4	; POSITIONING
	MOVE.B	(A5)+,(A4)+
	MOVE.B	#%00000000,(A4)+	; WRAPS MORE NICELY?
	DBRA	D6,.LOOP
	ADD.W	#bwpl*2-2,A2	; POSITIONING
	ADD.W	#bwpl*2-2,A4	; POSITIONING
	MOVE.B	#%00000000,(A4)	; WRAPS MORE NICELY?
	.SKIP:
	SUBI.W	#1,D7
	CMPI.W	#0,D7
	BEQ.W	.RESET
	MOVE.W	D7,FRAMESINDEX
	BRA.S	.SHIFTTEXT
	.RESET:
	ADDI.W	#1,TEXTINDEX
	MOVE.W	#3,D7
	MOVE.W	D7,FRAMESINDEX	; OTTIMIZZABILE

	.SHIFTTEXT:
	BSR.W	WaitBlitter
	LEA	TR808_END,A2
	LEA	TR808_END,A4
	SUB.W	#bwpl,A2			; POSITIONING
	SUB.W	#bwpl,A4			; POSITIONING
	MOVE.W	#$FFFF,BLTAFWM		; BLTAFWM lo spiegheremo dopo
	MOVE.W	#$FFFF,BLTALWM		; BLTALWM lo spiegheremo dopo
	MOVE.W	#%0010100111110000,BLTCON0	; BLTCON0 (usa A+D); con shift di un pixel
	MOVE.W	#%0000000000000010,BLTCON1	; BLTCON1 BIT 12 DESC MODE
	MOVE.W	#0,BLTAMOD		; BLTAMOD =0 perche` il rettangolo
	MOVE.W	#0,BLTDMOD		; BLTDMOD 40-4=36 il rettangolo
	MOVE.L	A2,BLTAPTH		; BLTAPT (fisso alla figura sorgente)
	MOVE.L	A4,BLTDPTH
	MOVE.W	#5*64+(wd+16)/16,BLTSIZE	; BLTSIZE (via al blitter !)
	RTS

__POPULATESPRITE:
	LEA	FONT,A1
	ADD.W	#2,A1
	ADD.W	#16*8,A1
	MOVE.L	A1,A2
	; ## TRANSFORM SONGPOS INTO ASCII TXT ##
	DIVU.W	#2,D3
	MOVE.W	#0,D1
	MOVE.W	D3,D2
	CMPI.W	#10,D3
	BLO.S	.oneDigit
	SUB.W	#10,D2
	MOVE.W	#1,D1
	.oneDigit:
	MULU.W	#8,D1
	MULU.W	#8,D2

	ADD.W	D1,A1
	ADD.W	D2,A2

	MOVEQ	#0,D6		; RESET D6
	MOVE.B	#6-1,D6
	.LOOP:
	MOVE.L	#0,D3
	MOVE.B	(A1),D3
	LSL.L	#6,D3
	MOVE.B	(A2),D3
	LSL.L	#2,D3
	LSL.L	#8,D3
	MOVE.B	(A1)+,D3
	LSL.L	#6,D3
	MOVE.B	(A2)+,D3
	LSL.L	#2,D3
	MOVE.L	D3,(A4)+
	DBRA	D6,.LOOP
	RTS

__POINT_SPRITES:			; #### Point LOGO sprites
	LEA	Copper1\.SpritePointers,A1	; Puntatori in copperlist

	MOVE.L	#0,D0		; sprite 0
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)

	ADDQ.W	#8,A1
	MOVE.L	ACTUALSPRITE,D0	; sprite 1
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)

	ADDQ.W	#8,A1
	MOVE.L	#LED_OFF,D0	; sprite 5
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)

	ADDQ.W	#8,A1
	MOVE.L	#LED_ON,D0	; sprite 4
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)

	ADDQ.W	#8,A1
	MOVE.L	#0,D0		; sprite 2
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)

	ADDQ.W	#8,A1
	MOVE.L	#0,D0		; sprite 3
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)

	ADDQ.W	#8,A1
	MOVE.L	#0,D0		; sprite 6
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)

	ADDQ.W	#8,A1
	MOVE.L	#0,D0		; sprite 7
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)
	RTS

;********** Fastmem Data **********
SPRITE_Y:		DC.W 0
SPRITE_X:		DC.W 0
MOUSE_Y:		DC.B 0
MOUSE_X:		DC.B 0
LMBUTTON_STATUS:	DC.W 0
TEXTINDEX:	DC.W 0
FRAMESINDEX:	DC.W 3
COUNTDOWN:	DC.W 0
SKIP_TRIGGERED:	DC.W 0
SEQ_POS_ON:	DC.B $00,$61,$69,$71,$00,$81,$89,$91,$00,$A1,$A9,$B1,$00,$C1,$C9,$D1
SEQ_POS_OFF:	DC.B $59,$00,$00,$00,$79,$00,$00,$00,$99,$00,$00,$00,$B9,$00,$00,$00
SEQ_VPOS_ON:	DC.B $FF,$EF,$EF,$EF,$FF,$EF,$EF,$EF,$FF,$EF,$EF,$EF,$FF,$EF,$EF,$EF
SEQ_VPOS_OFF:	DC.B $EF,$FF,$FF,$FF,$EF,$FF,$FF,$FF,$EF,$FF,$FF,$FF,$EF,$FF,$FF,$FF
FRAMEINDEX:	DC.W 0
ACTUALSPRITE:	DC.L SPRT_K
KEYBLOCKS:	DC.W 0,15,37,58,105,124,153,178,226,251,291,337,380,412,444,0
;KEYBLOCKS:	DC.W 0,153,178,226,251,291,337,6,8,10,12,14,16,18
KEYBLOCKS_INDEX:	DC.L 0

DrawBuffer:	DC.L TR808	; pointers to buffers
ViewBuffer:	DC.L TR808	; to be swapped
FONT:		DC.L 0,0		; SPACE CHAR
		INCBIN "cosmicalien_font.raw",0
		EVEN
TEXT:		INCLUDE "textscroller.i"
		INCLUDE "med/MED_PlayRoutine.i"
		dcb.l	8,0
MED_MODULE:	INCLUDE "SCORE.i"	;<<<<< MODULE NAME HERE!
		dcb.l	8,0
; *******************************************************************
	SECTION "ChipData",DATA_C		;declared data that must be in chipmem
; *******************************************************************

MED_SAMPLES:	INCLUDE "SAMPLES.i"	;<<<<< MED SAMPLES IN CHIP RAM!!

;MED_MODULE:	INCBIN "LOST_OCTAMED_FILES_1_APPENDED.MED"
		DC.L 0,0	; DUMMY
TR808:		INCBIN "TR-808.raw"
TR808_END:	DS.B bpls*8
		DC.L 0,0	; DUMMY
		DC.L 0,0	; DUMMY

SPRT_K:	
	DC.W $0000,$0080
	DC.W $E00E,$E00E,$E00E,$E00E,$E00E,$E00E
	DC.W $E070,$E070,$E070,$E070,$E070,$E070
	DC.W $FF80,$FF80,$FF80,$FF80,$FF80,$FF80
	DC.W $FC70,$FC70,$FC70,$FC70,$FC70,$FC70
	DC.W $FC0E,$FC0E,$FC0E,$FC0E,$FC0E,$FC0E
	DC.W 0,0	; 2 word azzerate definiscono la fine dello sprite.

SPRT_A:	
	DC.W $0000,$0080
	.DATA:
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W 0,0	; 2 word azzerate definiscono la fine dello sprite.
	DC.L 0	; DUMMY

SPRT_N:	
	DC.W $0000,$0080
	.DATA:
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W 0,0	; 2 word azzerate definiscono la fine dello sprite.
	DC.L 0	; DUMMY

LED_ON:
	.VPOS:
	DC.B $EF	; Posizione verticale di inizio sprite (da $2c a $f2)
	.HPOS:
	DC.B $47	; Posizione orizzontale di inizio sprite (da $40 a $d8)
	DC.B $F2	; $50+13=$5d	; posizione verticale di fine sprite
	.CTRL:
	DC.B $00
	DC.W $E000,$E000,$E000,$E000,$E000,$E000
	DC.W 0,0	; 2 word azzerate definiscono la fine dello sprite.

LED_OFF:	
	.VPOS:
	DC.B $EF	; Posizione verticale di inizio sprite (da $2c a $f2)
	.HPOS:
	DC.B $49	; Posizione orizzontale di inizio sprite (da $40 a $d8)
	DC.B $F2	; $50+13=$5d	; posizione verticale di fine sprite
	.CTRL:
	DC.B $00
	DC.W $E000,$0000,$E000,$0000,$E000,$0000
	DC.W 0,0	; 2 word azzerate definiscono la fine dello sprite.

COPPER1:
	DC.W $1FC,0		; Slow fetch mode, remove if AGA demo.
	DC.W $8E,$3061		; 238h display window top, left | DIWSTRT - 11.393
	DC.W $90,$16D1		; and bottom, right.	| DIWSTOP - 11.457
	DC.W $92,$28		; Standard bitplane dma fetch start
	DC.W $94,$D8		; and stop eab.abime.net/showthread.php?t=69926
	DC.W $106,$0C00		; (AGA compat. if any Dual Playf. mode)
	DC.W $108,0		; bwid-bpl	;modulos
	DC.W $10A,0		; bwid-bpl	;RISULTATO = 80 ?
	DC.W $102,0		; SCROLL REGISTER (AND PLAYFIELD PRI)
	DC.W $104,%0000000000100100	; BPLCON2
	DC.W $100,bpls*$1000+$200	; enable bitplanes

	.BplPtrs:
	DC.W $E0,0
	DC.W $E2,0
	DC.W $E4,0
	DC.W $E6,0
	DC.W $E8,0
	DC.W $EA,0
	DC.W $EC,0
	DC.W $EE,0
	DC.W $F0,0
	DC.W $F2,0
	DC.W $F4,0
	DC.W $F6,0	; full 6 ptrs, in case you increase bpls

	.SpritePointers:
	DC.W $120,0,$122,0 ; 0
	DC.W $124,0,$126,0 ; 1
	DC.W $128,0,$12A,0 ; 2
	DC.W $12C,0,$12E,0 ; 3
	DC.W $130,0,$132,0 ; 4
	DC.W $134,0,$136,0 ; 5
	DC.W $138,0,$13A,0 ; 6
	DC.W $13C,0,$13E,0 ; 7

	.Palette:
	DC.W $0180,$0000,$0182,$0444,$0184,$0BBB,$0186,$0333
	DC.W $0188,$0222,$018A,$0667,$018C,$0556,$018E,$0FFF
	DC.W $0190,$0EEE,$0192,$0DDD,$0194,$0CA8,$0196,$0CCC
	DC.W $0198,$0AAA,$019A,$0999,$019C,$0888,$019E,$0777
	DC.W $01A0,$0666,$01A2,$0776,$01A4,$0878,$01A6,$0AA0
	DC.W $01A8,$0BBC,$01AA,$0620,$01AC,$0EE0,$01AE,$0F00
	DC.W $01B0,$0990,$01B2,$099A,$01B4,$0961,$01B6,$0A71
	DC.W $01B8,$0E81,$01BA,$0B40,$01BC,$0943,$01BE,$0EEF

	.Waits:
	; SEQ_LEDs
	;DC.W $EF01,$FF00			; horizontal position masked off
	;DC.W $0174,$E000,$0176,$E000	; SPR6DATA
	;DC.W $017C,$0000,$017E,$E000	; SPR7DATA
	;DC.W $F201,$FF00
	;DC.W $0174,$0000,$0176,$0000	; SPR6DATA
	;DC.W $017C,$0000,$017E,$0000	; SPR7DATA

	DC.W $FFDF,$FFFE		; allow VPOS>$ff

	DC.W $0A01,$FF00		; horizontal position masked off
	DC.W $019E,$0666

	DC.W $1001,$FF00		; horizontal position masked off
	DC.W $01A6,$0888		; SCROLLTEXT - $0D61
	DC.W $01A8,$0888		; SCROLLTEXT - $0D61
	;DC.W $018A,$0999		; SCROLLTEXT - $0D61

	DC.W $FFFF,$FFFE		; magic value to end copperlist_COPPER1:

SCREEN1:	DC.B 0		; Define storage for buffer 1
SCREEN2:	DC.B 0		; two buffers

END
