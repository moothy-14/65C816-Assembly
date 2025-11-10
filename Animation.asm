.include "SnesRegisterShorthand.inc"
.include "Snes_Init.asm"
.include "Header.inc"

.segment "BANK1"
Data:
	.incbin "PaletteData.pal"	;#$200 of Palette data stored from $018000
	.incbin "VramData.chr"		;Tile data stored from $018200

; Sprites can move, make animation and controller input

.code
Start:
		
    lda #%10000000  		;Force constant VBlank by turning off the screen.
    sta INIDISP				;INIDISP - Screen display register

	lda #%00000000			;Tile data in VRAM for BG1 $0000
	sta BG12NBA	
	
	lda #%00010000			;1x1 Tilemaps bg1, Tilemap in VRAM at $1000
	sta BG1SC

	lda #%00010001			;Sets BG1 to 16x16 characters, and BG mode to 1
	sta BGMODE	
	
	lda #%10000000			;inc on VMDATAH write
	sta VMAIN				;VMAIN - Video port control register
	
	lda #%01100000			;sprites are 16x16 & 32x32, at VRAM $0000-$1000
	sta OBJSEL
	
	lda #%00010001
	sta TM					;Enable OBJ and BG1 on main screen
	
;-----------Setting palette data--------------

	lda #$01
	pha
	plb						;sets Bank register to $01
	
	clc
	ldx #$00
	
	@loop:
	
	lda $8000, X
	sta CGDATA
	
	inx
	cpx #$200
	bne @loop

;-----------Setting Tile data------------------

LoadTileData:				;Tile Data stored from $018200
	
	ldx #$00
	
	@loop:
	
	lda $8200, X
	sta VMDATAL
	inx
	
	lda $8200, X
	sta VMDATAH
	inx
	
	cpx #$2000
	bcc @loop


;------------------------Setting tilemap & OAM---------------------

	ACTIVETILE = $00
	CURRENTADDRESS = $02
	NUMLINES = $04
	TILEMAPSTART = $06
	OAMSTART = $08
	ANIMATIONTIMERS = $10 ;From $10-$XX

	lda #$00
	pha
	plb						;Data Bank register to $0
	
	
	jsr Tilemap_Init		;Sets Tilemap data at $7E2000
	
	jsr OAM_Init			;Sets OAM data after end of Tilemap
	
	lda #$00
	pha
	plb						;Set Bank register to $00
	
	jsr DMA_Setup
	
	lda #%10000000
	sta NMITIMEN			;Enable NMI
	
	wai	
	
	lda #%00001111			;End VBlank, max brightness
	sta INIDISP
	
	
	ldx #$00
	ldy #$00
	phx						;Add 2 bytes of 0s to stack for Sprite_Palette_Rotate
	phx						;Add 2 bytes of 0s to stack for Sprite_Move				
	
	lda #$7E
	pha
	plb						;Set Bank register to $7E
	
	lda (OAMSTART)
	sta $3, S
	
	lda #$00
	pha
	plb						;Set Bank register to $7E
	
	jmp Forever
	
Forever:
	jsr DMA_Reset
	
	jsr Sprite_Palette_Rotate
	
	jsr Sprite_Move
	
	@wait:
	wai
	bra Forever
	
	
Irq_end:
	rti
	
Irq:
	rti

Nmi:
	lda #%00000011
	sta MDMAEN 				;Enable DMA transfer on channels 0-1
	
	lda #$00
	sta OAMADDL
	
	lda #$01
	sta OAMADDH				;Set OAMADD to start of properties table
	
	lda #%00000100
	sta MDMAEN				;Enable DMA transfer on channel 2
	
	rti

;----------------------FUNCTIONS---------------------

.proc Tilemap_Init			;Sets Tilemap data at $7E2000
	
	lda #$7E				;Set to wram bank 1
	pha
	plb
	
	rep #%00100000			;A to 16 bit mode
	
	lda #$2000
	sta TILEMAPSTART		;Tilemap starts at $(7E)2000
	sta CURRENTADDRESS		;Start Pointer at $(7E)2000
	
	lda #$2					;Grass Floor
	sta ACTIVETILE
	lda #$9					;9 lines
	sta NUMLINES
	
	jsr Load_Tilemap_Lines
	
	lda #$4					;Grass block
	sta ACTIVETILE
	lda #$1					;1 line
	sta NUMLINES
	
	jsr Load_Tilemap_Lines
	
	lda #$6					;Dirt Block
	sta ACTIVETILE	
	lda #$1					;1 line
	sta NUMLINES
	
	jsr Load_Tilemap_Lines
	
	lda #$8					;Stone
	sta ACTIVETILE
	lda #$3					;3 lines
	sta NUMLINES
	
	jsr Load_Tilemap_Lines
	
	sep #%00100000			;Accumulator back to 8 bit
	rts
	
.endproc

.proc Load_Tilemap_Lines	;Writes Lines of Tilemap

	.A16
	
	ldx #$00				;loop Counter
	ldy #$00				;Row Counter
	
	clc
	
	loop:
	lda ACTIVETILE			;Tile (16x16, $## is top left corner)
	sta (CURRENTADDRESS)	;Write to location pointed to by CURRENTADDRESS
	inc CURRENTADDRESS			
	inc CURRENTADDRESS		;Increase location by 2
	inx
	cpx #$10
	bcc loop
	
	
	
	clc
	
	lda CURRENTADDRESS			
	adc #$0020
	sta CURRENTADDRESS		;Increase location by $20 (Loops to next line)
	
	ldx #$0000
	
	iny
	cpy NUMLINES
	bne loop
	
	clc
	rts	
.endproc

.proc OAM_Empty				;Initializes OAM to empty values

	rep #%00100000			;A to 16 bit mode
	
	clc
	lda TILEMAPSTART
	adc #$800
	sta OAMSTART
	sta CURRENTADDRESS
	
	ldx #$0
	lda #$0
	
	loop:
	sta (CURRENTADDRESS)
	inc CURRENTADDRESS
	inc CURRENTADDRESS
	inx
	cpx #$110				;544 byte area, dual byte writes
	bne loop
	
	lda OAMSTART
	sta CURRENTADDRESS
	
	sep #%00100000			;A to 8 bit mode
	rts
	
	
.endproc

.proc OAM_Init				;Adds sprite data
	
	jsr OAM_Empty
	
	
	ldx #$0
	clc
	
	lda #$00				;X pos of sprite 0
	sta (CURRENTADDRESS)
	inc CURRENTADDRESS
	
	lda #$80				;Y pos of sprite 0
	sta (CURRENTADDRESS)
	inc CURRENTADDRESS
	
	lda #$A					;Tile number
	sta (CURRENTADDRESS)
	inc CURRENTADDRESS
	
	lda #%00110000			;attributes
	sta (CURRENTADDRESS)
	inc CURRENTADDRESS
	
	rep #%00100000			;A to 16 bit mode
	lda OAMSTART
	adc #$200
	sta CURRENTADDRESS		;Set CURRENTADDRESS to start of OAM properties table
	sep #%00100000			;A to 8 bit mode
	
	lda #%000000000			;Small sprite 0
	sta (CURRENTADDRESS)
	rts
.endproc

.proc DMA_Setup
	;Channel 0 is Tilemap
	;Channel 1 is OAM Main Table
	;Channel 2 is OAM properties table
	
	rep #%00100000			;A to 16 bit mode
	
	
	lda TILEMAPSTART
	sta A1T0L				;High-low bytes of tilemap wram location
	
	lda OAMSTART
	sta A1T1L				;High-low bytes of OAM main table wram location
	
	clc
	adc #$0200				;Properties table is right after main table
	sta A1T2L				;First 2 bytes of OAM properties table wram location
	
	
	lda #$0800
	sta DAS0L				;Set to write $800 bytes to vram (1 kiloword tilemap)
	
	lda #$0200
	sta DAS1L				;Set to write $200 bytes to OAM (512 byte table)
	
	lda #$0020
	sta DAS2L				;Set to write $20 bytes to OAM (32 byte table)
	
	
	lda #$1000
	sta VMADDL				;Set Vram Address to vram Tilemap start
	
	lda #$0000
	sta OAMADDL				;Set OAM Address to Main Table start
	
	sep #%00100000			;A to 8 bit mode
	
	lda #$7E
	sta A1B0
	sta A1B1
	sta A1B2				;Sets wram bank to $7E
	
	lda #$18				;Low byte of VMDATA location $2118
	sta BBAD0
	
	lda #$04				;Low byte of OAMDATA location $2104
	sta BBAD1
	sta BBAD2
	
	lda #%00000001			;Write 2 bytes into Low-High registers
	sta DMAP0
	
	lda #%00000010			;Write twice to one register
	sta DMAP1
	sta DMAP2

	rts
.endproc

.proc Timer_Decrement
	;Loops through list of animation timers,
	;and decrements them if they aren't 0
	
	ldx #$00				;X counts the sprite number
	
	@loop:
	cpx #$01
	beq @end				;Loop counter
	
	lda $10, X				;Starts at $10 b/c increases X first thing
	cmp $00
	beq @return				;If timer is 0, inx then go to next loop iteration
	
	dec $10, X
	
	@return:
	inx
	bra @loop
	
	@end:
	rts	
	
.endproc

.proc DMA_Reset
	;Channel 0 is Tilemap
	;Channel 1 is OAM Main Table
	;Channel 2 is OAM properties table
	
	rep #%00100000			;A to 16 bit mode
	
	
	lda TILEMAPSTART
	sta A1T0L				;High-low bytes of tilemap wram location
	
	lda OAMSTART
	sta A1T1L				;High-low bytes of OAM main table wram location
	
	clc
	adc #$0200				;Properties table is right after main table
	sta A1T2L				;High-low bytes of OAM properties table wram location
	
	
	lda #$0800
	sta DAS0L				;Set to write $800 bytes to vram (1 kiloword tilemap)
	
	lda #$0200
	sta DAS1L				;Set to write $200 bytes to OAM (512 byte table)
	
	lda #$0020
	sta DAS2L				;Set to write $20 bytes to OAM (32 byte table)
	
	
	lda #$1000
	sta VMADDL				;Set Vram Address to vram Tilemap start
	
	lda #$0000
	sta OAMADDL				;Set OAM Address to Main Table start
	
	lda #$0000
	sep #%00100000			;A to 8 bit mode
	rts
.endproc

.proc Sprite_Palette_Rotate ;Changes the Sprite Palette once every 
	; X Counts the number of frames
	; Y counts the palette
	
	;Pulls values from the stack
	lda $3, S	
	tay

	lda $4, S
	tax
	
	inx
	cpx #$06
	bne @return				;If X is not a multiple of #$06, return
	
	iny
	
	lda #$7E
	pha
	plb						;Data bank register to $7E
	
	rep #%00100000			;Accumulator 16 bit mode
	
	clc
	lda OAMSTART			
	adc #$3
	sta CURRENTADDRESS		;Set current address to OAM Sprite 0 attribute
	
	lda #$0000
	sep #%00100000			;Accumulator 8 bit mode
	
	tya
	asl						;Moves palette number to start at $10 of byte
	clc
	adc #%00110000			;Sets sprite to highest priority
	sta (CURRENTADDRESS)	;Write to OAM
	
	lda #$00
	pha
	plb						;Data bank register to $00
	
	ldx #$00
	clc
	cpy #%00000111			;Loop back to palette 0
	bne @return
	
	ldy #$00
	
	
	@return:				;Sets values on stack before returning
	tya
	sta $3, S	

	txa
	sta $4, S
	rts
	
.endproc

.proc Sprite_Move 			;Moves the Sprite x-position once every 
	; X Counts the number of frames
	; Y counts x-position
	
	;Pulls values from the stack
	lda $5, S	
	tay

	lda $6, S
	tax
	
	inx
	cpx #$02
	bne @return				;If X is not a multiple of #$06, return
	
	iny
	
	lda #$7E
	pha
	plb						;Data bank register to $7E
	
	rep #%00100000			;Accumulator 16 bit mode
	
	clc
	lda OAMSTART			
	sta CURRENTADDRESS		;Set current address to OAM Sprite 0 x pos
	
	lda #$0000
	sep #%00100000			;Accumulator 8 bit mode
	
	tya
	clc
	sta (CURRENTADDRESS)	;Write to OAM
	
	lda #$00
	pha
	plb						;Data bank register to $00
	
	ldx #$00
	clc
	cpy #$FF				;Loop back to x=0 after 255
	bne @return
	
	ldy #$00
	
	
	@return:				;Sets values on stack before returning
	tya
	sta $5, S	

	txa
	sta $6, S
	rts
	
.endproc
