SECTION "boot", ROM0[$100]
boot:
	di
	jp main 
REPT $150 - $104
	db 0
ENDR
