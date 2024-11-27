CC=gcc
LD=gcc
SPIN=spin

USERCFLAGS=

SRCDIR=src
BUILDDIR=build

all: pan

help:
	@echo 'TODO: help message'

pan: $(BUILDDIR)/pan.c
	$(LD) -DNXT -o $@ $<

$(BUILDDIR)/pan.c: $(SRCDIR)/proto.pml $(BUILDDIR)
	cd $(BUILDDIR) && $(SPIN) -a $(USERCFLAGS) ../$<

$(BUILDDIR):
	mkdir -p $@

clean:
	rm -rf $(BUILDDIR)
	rm -f pan *.pml.trail pan.*

test:
	@for i in $$(seq 5 -1 2); do ./test.sh $$i; done

.PHONY: clean help test
