INCLUDE "hardware.inc"

SECTION "board", WRAM0
Board1:    DS 8	;; 8x8 matrix for the game of life.
Board2:    DS 8	;; 
Board1Ptr: DS 2
Board2Ptr: DS 2

SECTION "main", ROM0
EXPORT main
main:
	call	initlcd
	call	init
.loop
	call	step
	jr	.loop

init:
	ld	hl, Board1
	ld	c, $8
	call	bzero
	ld	hl, Board2
	ld	c, $8
	call	bzero

	ld	hl, Board1Ptr
	ld	bc, Board1
	ld	[hl], c
	inc	hl
	ld	[hl], b

	ld	hl, Board2Ptr
	ld	bc, Board2
	ld	[hl], c
	inc	hl
	ld	[hl], b

	call	block
	ret

block:
	call	swapboards
	ld	b, $0	
	ld	c, $1
	call	setcell
	ld	b, $1
	ld	c, $2
	call	setcell
	ld	b, $2
	ld	c, $0
	call	setcell
	ld	b, $2
	ld	c, $1
	call	setcell
	ld	b, $2
	ld	c, $2
	call	setcell
	call	swapboards
	ret

swapboards:
.prologue
	push	bc
	push	de
.start
	ld	hl, Board1Ptr
	call	deref
	ld	b, h
	ld	c, l

	ld	hl, Board2Ptr
	call	deref
	ld	d, h
	ld	e, l

	ld	hl, Board1Ptr
	ld	[hl], e
	inc	hl
	ld	[hl], d

	ld	hl, Board2Ptr
	ld	[hl], c
	inc	hl
	ld	[hl], b
.epilogue
	pop	de
	pop	bc
	ret

;; Shift the value $01 into 'A' by 'C' bits. For example, the following
;; snippet will load the value $08 into 'A'.
;; 	ld	c, $03
;;	call	onemask
;; Other examples: C=$00 -> A=$01, C=$07 -> A=$80
onemask:
.prologue
	push	bc

	ld	a, $1
	inc	c
.loop
	dec	c
	jr	z, .done
	rla
	jr	.loop
.done
.epilogue
	pop	bc
	ret


deref:
	ld	a, [hl+]
	ld	h, [hl]
	ld	l, a
	ret

getcell:
.prologue
	push	de
.start
	;; B = row, C = col
	ld	hl, Board1Ptr
	call	deref
	ld	d, 0
	ld	e, b
	add	hl, de		; Load 'HL' with address of row
	call	onemask		; Load 'A' with (1 << 'C').
	and	a, [hl]		; essentially: row | (1 << C)
.epilogue
	pop	de
	ret

setcell:
.prologue
	push	de
.start
	;; B = row, C = col
	ld	hl, Board2Ptr
	call	deref

	ld	d, 0
	ld	e, b
	add	hl, de		; Load 'HL' with address of row
	call	onemask		; Load 'A' with (1 << 'C').
	or	a, [hl]		; essentially: row | (1 << C)
	ld	[hl], a
.epilogue
	pop	de
	ret


clrcell:
.prologue
	push	de
.start
	;; B = row, C = col
	ld	hl, Board2Ptr
	call	deref

	ld	d, 0
	ld	e, b
	add	hl, de		; Load 'HL' with address of row
	call	onemask		; Load 'A' with (1 << 'C').
	cpl			; Flip mask bits in 'A'
	and	a, [hl]		; essentially: row & ~(1 << C)
	ld	[hl], a
.epilogue
	pop	de
	ret


decwrap:
	or	a, a
	jr	z, .min
	dec	a
	ret
.min
	ld	a, $7	; TODO: magic number
	ret


incwrap:
	cp	a, $7	; TODO: magic number
	jr	z, .max
	inc	a
	ret
.max
	xor	a, a
	ret
	

;; Decrement 'D' if the zero flag is not set.
incdifnz:
	jr	z, .zero
	inc	d
.zero
	ret

;; Given a coordinate in 'BC' (B = row, and C = col), set 'A' equal to
;; the number of live neighbors.
neighbors:
.prologue
	push	bc
	push	de

.start
	;; B = row, C = col
	ld	d, $0	; number of neighbors

	;; (-1, -1)
	ld	a, b
	call	decwrap	
	ld	b, a
	ld	a, c
	call	decwrap	
	ld	c, a
	call	getcell
	call	incdifnz

	;; (-1, 0)
	ld	a, c
	call	incwrap	
	ld	c, a
	call	getcell
	call	incdifnz

	;; (-1, 1)
	ld	a, c
	call	incwrap	
	ld	c, a
	call	getcell
	call	incdifnz

	;; (0, 1)
	ld	a, b
	call	incwrap	
	ld	b, a
	call	getcell
	call	incdifnz

	;; (1, 1)
	ld	a, b
	call	incwrap	
	ld	b, a
	call	getcell
	call	incdifnz
	
	;; (1, 0)
	ld	a, c
	call	decwrap	
	ld	c, a
	call	getcell
	call	incdifnz

	;; (1, -1)
	ld	a, c
	call	decwrap	
	ld	c, a
	call	getcell
	call	incdifnz

	;; (0, -1)
	ld	a, b
	call	decwrap	
	ld	b, a
	call	getcell
	call	incdifnz

	ld	a, d

.epilogue
	pop	de
	pop	bc
	ret
	

stepcell:
	;; B = row, C = col
	call	getcell
	jr	z, .cellisdead
.cellisalive
	call	neighbors
	cp	a, $2
	jr	c, .setdead
	cp	a, $4
	jr	nc, .setdead
	jr	.setalive
.cellisdead
	call	neighbors
	cp	a, $3
	jr	z, .setalive
	jr	.setdead
.setdead
	call 	clrcell
	ret
.setalive
	call	setcell
	ret

step:
	ld	b, $0
	ld	c, $0
.loop
	call	stepcell
	inc	c
	ld	a, c
	cp 	a, $8
	jr	nz, .loop
	inc	b
	ld	a, b
	cp 	a, $8
	jr	z, .done
	ld	c, $0
	jr	.loop
.done
	call	swapboards
	call	draw
	ret

drawcell:
	push	bc
	push	de

	call	getcell
	jr	z, .dead
.alive
	ld	a, $01
	jr	.cont
.dead
	ld	a, $00
.cont
;;  	push	af
;;  	ld	a, b
;;  	srl	a
;;  	srl	a
;;  	srl	a
;;  	add	a, c
;;  	ld	c, a
;;  	and	a, $F0
;;  	ld	b, a
;;  	swap	b
;;  	ld	a, c
;;  	swap	a
;;  	and	a, $F0
;;  	ld	c, a
;;  	ld	hl, $9000
;;  	add	hl, bc
;;  	pop	af

	ld	hl, $9800
	ld	b, 0
	add	hl, bc

	call	waitvblank
	ld	d, 16
.blackloop
	ld	[hl+], a
	dec	d
	jr	nz, .blackloop
	
	pop	de
	pop	bc
	ret	

draw:
	ld	b, $0
	ld	c, $0
.loop
	call	drawcell
	inc	c
	ld	a, c
	cp 	a, $8
	jr	nz, .loop
	inc	b
	ld	a, b
	cp 	a, $8
	jr	z, .done
	ld	c, $0
	jr	.loop
.done
	ret

;; Zero out a section of memory. Caller must set 'HL' to point the base
;; of the memory region. 'C' is the number of bytes to clear.
EXPORT bzero
bzero:
	xor	a, a
.loop
	ld	[hl+], a
	dec	c
	jr	nz, .loop
	ret

;; Busy wait for the vertical blanking period. The gameboy hardware
;; disallows read/writes into video ram when the display is not in a
;; blanking period.
EXPORT waitvblank
waitvblank:
	push	af
.loop
	ld	a, [rLY]
	cp	$90
	jr	c, .loop
	pop	af
	ret

initlcd:
	call	waitvblank

	;; Disable the LCD
	xor	a, a
	ld	[rLCDC], a

	;; Reset scroll registers
	xor	a, a
	ld	[rSCY], a
	ld	[rSCX], a

	;; Set the palette
	ld	a, %11100100
	ld	[rBGP], a

	;; Turn off sound
	ld	[rNR52], a

	;; Set all background sprites to sprite $1
	ld	a, $40
	ld	d, $4
	ld	e, $0
	ld	hl, $9800
.screenloop
	ld	[hl+], a
	dec	e
	jr	nz, .screenloop
	dec	d
	jr	nz, .screenloop

	;; Set all background sprites to sprite $0
	ld	a, 0
	ld	d, 8
	ld	e, 8
	ld	b, 0
	ld	c, 24
	ld	hl, $9800
.screenloop2
	ld	[hl+], a
	dec	d
	jr	nz, .screenloop2
	dec	e
	ld	d, 8
	add	hl, bc
	jr	nz, .screenloop2

	;; Set sprite $40 to all black.
	;; This will black out the entire screen.
	ld	d, 16
	ld	a, $FF
	ld	hl, $9400
.blackloop
	ld	[hl+], a
	dec	d
	jr	nz, .blackloop

	;; Turn screen on, display background
	ld	a, %10000001
	ld	[rLCDC], a
	ret

