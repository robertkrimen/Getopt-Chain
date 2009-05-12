.PHONY: all test time clean distclean dist distcheck upload distupload

all: test

dist:
	rm -rf inc META.y*ml
	perl Makefile.PL
	$(MAKE) -f Makefile dist

install distclean tardist: Makefile
	$(MAKE) -f $< $@

test: Makefile
	perl Makefile.PL
	TEST_RELEASE=1 $(MAKE) -f $< $@

Makefile: Makefile.PL
	perl $<

clean: distclean

reset: clean
	rm -rf inc META.y*ml
	perl Makefile.PL
	$(MAKE) test
