CC=gcc
LD=gcc
SPIN=spin

SRCDIR=src
BUILDDIR=build

all: pan

help:
	@echo 'TODO: help message'

pan: $(BUILDDIR)/pan.c
	$(LD) -DNXT -o $@ $<

$(BUILDDIR)/pan.c: $(SRCDIR)/proto.pml $(BUILDDIR)
	cd $(BUILDDIR) && $(SPIN) -a ../$<

$(BUILDDIR):
	mkdir -p $@

clean:
	rm -rf $(BUILDDIR)
	rm -f pan *.pml.trail pan.*

.PHONY: clean help
