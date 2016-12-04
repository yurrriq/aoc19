IDRIS ?= idris
OPTS  ?= -p contrib -p lightyear -i src

.PHONY: shell

all: output/day01.txt output/day02.txt

bin/day%: src/Data/Advent/Day%.idr input/day%.txt
	@mkdir -p bin
	$(IDRIS) $(OPTS) -o $@ $<

output/day%.txt: bin/day%
	@mkdir -p output
	$< >$@

clean:
	find . -name '*.ibc' -delete
	rm -fr bin/ output/

shell:
	nix-shell -p haskellPackages.idris gcc gmp
