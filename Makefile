TARG     = life.gb
RGBASM   = rgbasm
RGBLINK  = rgblink
RGBFIX   = rgbfix
INCFILES = hardware.inc
OFILES   = main.o boot.o

$(TARG) : $(OFILES)
	$(RGBLINK) -o $@ $(OFILES)
	$(RGBFIX) -v $@

$(OFILES) : $(INCFILES)

.s.o:
	$(RGBASM) -o $@ -i inc/ $<

run: $(TARG)
	rlwrap ./sameboy $(TARG)

clean:
	rm -f $(TARG) $(OFILES)

.SUFFIXES:
.SUFFIXES: .s .inc .o
