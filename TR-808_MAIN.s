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
TrigShift		EQU 7
PXLSIDE		EQU 16
Z_Shift		EQU PXLSIDE*5/2	; 5x5 obj
LOGOSIDE		EQU 16*7
LOGOBPL		EQU LOGOSIDE/16*2
MARGINX		EQU wd/2
MARGINY		EQU LOGOSIDE/2
BLIT_POSITION	EQU (bwpl/2-LOGOBPL/2)+((LOGOSIDE+16)*40-2)
BPL_BLIT_OFFSET	EQU BLIT_POSITION+bwpl*hg*4		; we precalculate :)
TXT_FRMSKIP 	EQU 3
;*************
MODSTART_POS 	EQU 1-1		; start music at position # !! MUST BE EVEN FOR 16BIT
;*************

;CLR.W	$100		; DEBUG | w 0 100 2
;********** Demo **********	; Demo-specific non-startup code below.
Demo:				; a4=VBR, a6=Custom Registers Base addr
	;*--- init ---*
	MOVE.L	#VBint,$6C(A4)
	MOVE.W	#%1110000000100000,INTENA
	;** SOMETHING INSIDE HERE IS NEEDED TO MAKE MOD PLAY! **
	;move.w	#%1110000000000000,INTENA	; Master and lev6	; NO COPPER-IRQ!
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
	; #### CPU INTENSIVE TASKS BEFORE STARTING MUSIC

	move.b	$DFF00A,MOUSE_Y
	move.b	$DFF00B,MOUSE_X

	BSR.W	__POINT_SPRITES	; #### Point sprites

	;CLR.W	$100		; DEBUG | w 0 100 2
	; in photon's wrapper comment:;move.w d2,$9a(a6) ;INTENA
	JSR	_startmusic
	
	MOVE.L	#COPPER1,COP1LC		; COP1LCH
;********************  main loop  ********************
MainLoop:
	move.w	#$12c,d0	;No buffering, so wait until raster
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
	MOVE.L	#TR808,DrawBuffer
	; do stuff here :)
	BSR.W	LeggiMouse	; questa legge il mouse
	MOVE.W	SPRITE_Y(PC),D0	; prepara i parametri per la routine
	MOVE.W	SPRITE_X(PC),D1	; universale
	LEA	SPRT_K,A1	; indirizzo sprite
	MOVEQ	#16,D2		; altezza sprite
	BSR.W	UniMuoviSprite	; chiama la routine universale
		
	BSR.W	__FILLANDSCROLLTXT

	;*--- main loop end ---*

	ENDING_CODE:
	BTST	#6,$BFE001
	BEQ.S	.quit		; then loop
	;BNE.S	.DontShowRasterTime
	;MOVE.W	#$0FF,$DFF196	; show rastertime left down to $12c
	;.DontShowRasterTime:
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
	CLR.W	$100		; DEBUG | w 0 100 2
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

	CMPI.W	#hg-15,D0
	BLO.S	.Y_B_ok
	MOVE.W	#hg-15,SPRITE_Y
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
	LEA	SEQ_POS_BIT,A0
	MOVE.B	(A0,D0.W),LED_ON\.CTRL
	MOVE.B	(A0,D0.W),LED_OFF\.CTRL
	RTS

__FILLANDSCROLLTXT:
	MOVE.W	FRAMESINDEX,D7
	CMPI.W	#3,D7
	BNE.W	.SKIP
	MOVEM.L	ViewBuffer,A4	; Trick for double buffering ;)
	LEA	FONT,A5
	LEA	TEXT,A3
	ADD.W	#bwpl*(hg-9)+1,A4	; POSITIONING
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
	MOVEM.L	ViewBuffer,A2	; DOUBLE
	MOVE.L	DrawBuffer,A4	; BUFFERING ;)
	ADD.W	#bwpl*(hg-1),A2	; POSITIONING
	ADD.W	#bwpl*(hg-1),A4	; POSITIONING
	MOVE.W	#$FFFF,BLTAFWM	; BLTAFWM lo spiegheremo dopo
	MOVE.W	#$000F,BLTALWM	; BLTALWM lo spiegheremo dopo
	MOVE.W	#%0010100111110000,BLTCON0	; BLTCON0 (usa A+D); con shift di un pixel
	MOVE.W	#%0000000000000010,BLTCON1	; BLTCON1 BIT 12 DESC MODE
	MOVE.W	#3,BLTAMOD	; BLTAMOD =0 perche` il rettangolo
	MOVE.W	#3,BLTDMOD	; BLTDMOD 40-4=36 il rettangolo
	MOVE.L	A2,BLTAPTH	; BLTAPT  (fisso alla figura sorgente)
	MOVE.L	A4,BLTDPTH
	MOVE.W	#5*64+(wd-10)/16,BLTSIZE	; BLTSIZE (via al blitter !)
	RTS

__POINT_SPRITES:			; #### Point LOGO sprites
	LEA	Copper1\.SpritePointers,A1	; Puntatori in copperlist
	MOVE.L	#SPRT_K,D0	; sprite 0
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)

	ADDQ.W	#8,A1
	MOVE.L	#0,D0		; sprite 1
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
	MOVE.L	#0,D0		; sprite 4
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)

	ADDQ.W	#8,A1
	MOVE.L	#0,D0		; sprite 5
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)

	ADDQ.W	#8,A1
	MOVE.L	#LED_ON,D0	; sprite 6
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)

	ADDQ.W	#8,A1
	MOVE.L	#LED_OFF,D0	; sprite 7
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)
	RTS






;********** Fastmem Data **********
SPRITE_Y:		DC.W 0	; qui viene memorizzata la Y dello sprite
SPRITE_X:		DC.W 0	; qui viene memorizzata la X dello sprite
MOUSE_Y:		DC.B 0	; qui viene memorizzata la Y del mouse
MOUSE_X:		DC.B 0	; qui viene memorizzata la X del mouse
LMBUTTON_STATUS:	DC.W 0
TEXTINDEX:	DC.W 0
FRAMESINDEX:	DC.W 3
END_TEXT_LEN:	DC.W 152

SEQ_POS_ON:	DC.B $00,$51,$5C,$65,$00,$7A,$84,$8E,$00,$A3,$AD,$B8,$00,$CD,$D8,$E2
SEQ_POS_BIT:	DC.B $1,$1,$0,$1,$0,$0,$1,$1,$0,$0,$1,$0,$1,$0,$1,$1
SEQ_POS_OFF:	DC.B $47,$00,$00,$00,$70,$00,$00,$00,$99,$00,$00,$00,$C2,$00,$00,$00

DrawBuffer:	DC.L SCREEN2		; pointers to buffers
ViewBuffer:	DC.L SCREEN1		; to be swapped

FONT:		DC.L 0,0			; SPACE CHAR
		INCBIN "cosmicalien_font.raw",0
		EVEN

END_TEXT:	DC.B "THANKS FOR EXECUTING MECHMICROBES BY KONEY!",10
		DC.B "YOU REACHED BLOCK "
		TXT_POS: DC.B "XX"
		DC.B " FROM A SEQUENCE OF 76. ",10
		DC.B "VISIT WWW.KONEY.ORG FOR MORE TECHNO "
		DC.B "AND HARDCORE AMIGA STUFF!",10
		EVEN

TEXT:		INCLUDE "textscroller.i"

		INCLUDE	"med/MED_PlayRoutine.i"

	SECTION "ChipData",DATA_C	;declared data that must be in chipmem

TR808:		INCBIN "TR-808.raw"

MED_MODULE:	INCBIN	"med/LOSTMEDFILES_MMD1.med"	;<<<<< MODULE NAME HERE!

SPRT_K:	
	DC.B	$50	; Posizione verticale di inizio sprite (da $2c a $f2)
	DC.B	$90	; Posizione orizzontale di inizio sprite $44
	DC.B	$60	; $50+13=$5d	; posizione verticale di fine sprite
	DC.B	$00
	DC.W	$E00E,$E00E,$E00E,$E00E,$E00E,$E00E
	DC.W	$E070,$E070,$E070,$E070,$E070,$E070
	DC.W	$FF80,$FF80,$FF80,$FF80,$FF80,$FF80
	DC.W	$FC70,$FC70,$FC70,$FC70,$FC70,$FC70
	DC.W	$FC0E,$FC0E,$FC0E,$FC0E,$FC0E,$FC0E
	DC.W	0,0	; 2 word azzerate definiscono la fine dello sprite.

LED_ON:
	.VPOS:
	DC.B $90	; Posizione verticale di inizio sprite (da $2c a $f2)
	.HPOS:
	DC.B $47	; Posizione orizzontale di inizio sprite (da $40 a $d8)
	DC.B $00	; $50+13=$5d	; posizione verticale di fine sprite
	.CTRL:
	DC.B $00
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W 0,0	; 2 word azzerate definiscono la fine dello sprite.
LED_OFF:	
	.VPOS:
	DC.B $90	; Posizione verticale di inizio sprite (da $2c a $f2)
	.HPOS:
	DC.B $00	; Posizione orizzontale di inizio sprite (da $40 a $d8)
	DC.B $00	; $50+13=$5d	; posizione verticale di fine sprite
	.CTRL:
	DC.B $00
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
	DC.W $0000,$0000,$0000,$0000,$0000,$0000
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
	DC.W $01A0,$0666,$01A2,$0776,$01A4,$0878,$01A6,$0EEF
	DC.W $01A8,$0BBC,$01AA,$099A,$01AC,$0620,$01AE,$0AA0
	DC.W $01B0,$0990,$01B2,$0EE0,$01B4,$0961,$01B6,$0A71
	DC.W $01B8,$0E81,$01BA,$0B40,$01BC,$0943,$01BE,$0F00

	.Waits:
	; SEQ_LEDs
	DC.W $F801,$FF00			; horizontal position masked off
	DC.W $0174,$FC00,$0176,$FC00	; SPR6DATA
	DC.W $017C,$0000,$017E,$FC00	; SPR7DATA
	DC.W $FA01,$FF00
	DC.W $0174,$0000,$0176,$0000	; SPR6DATA
	DC.W $017C,$0000,$017E,$0000	; SPR7DATA

	;DC.W $FF01,$FF00		; horizontal position masked off
	;DC.W $018E,$0BBB		; SCROLLTEXT - $0D61

	DC.W $FFDF,$FFFE		; allow VPOS>$ff

	DC.W $FFFF,$FFFE		; magic value to end copperlist_COPPER1:


; *******************************************************************
	SECTION	ChipBuffers,BSS_C	;BSS doesn't count toward exe size
; *******************************************************************

SCREEN1:		DS.B 0		; Define storage for buffer 1
SCREEN2:		DS.B bwid*hg	; two buffers

END
