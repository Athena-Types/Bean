.DEFAULT_GOAL := small
TESTDIR := $(shell pwd)/benchmarks

DOTPROD := /dotprod/DotProd
HORNER := /horner/Horner
POLYVAL := /polyval/PolyVal
MATVECMUL := /matvecmul/MatVecMul
SUM := /sum/Sum

# Tests that run in just a few seconds
SMALL_TEST_INPUTS := \
	$(DOTPROD)20 $(DOTPROD)50 $(DOTPROD)100 \
	$(HORNER)20 $(HORNER)50 $(HORNER)100 \
	$(POLYVAL)10 $(POLYVAL)20 $(POLYVAL)50 \
	$(MATVECMUL)5 $(MATVECMUL)10 $(MATVECMUL)20 \
	$(SUM)50 $(SUM)100 $(SUM)500 \
	/Cos /Sine

# All tests
ALL_TEST_INPUTS := \
	$(DOTPROD)20 $(DOTPROD)50 $(DOTPROD)100 $(DOTPROD)500 \
	$(HORNER)20 $(HORNER)50 $(HORNER)100 $(HORNER)500\
	$(POLYVAL)10 $(POLYVAL)20 $(POLYVAL)50 $(POLYVAL)100 \
	$(MATVECMUL)5 $(MATVECMUL)10 $(MATVECMUL)20 $(MATVECMUL)50 \
	$(SUM)50 $(SUM)100 $(SUM)500 $(SUM)1000 \
	/Cos /Sine

$(ALL_TEST_INPUTS): 
	@printf "*** START BENCHMARK: $@ *** \n"
	@dune exec -- bean $(TESTDIR)/$@.be -u 53
	@printf "*** END BENCHMARK: $@ *** \n \n"

.PHONY: run_small small run_all all clean $(SMALL_TEST_INPUTS) $(ALL_TEST_INPUTS)

run_small: $(SMALL_TEST_INPUTS)

small: 
	@dune build
	@$(MAKE) run_small > benchmarks.txt 2>&1

run_all: $(ALL_TEST_INPUTS)

all:
	@dune build
	@$(MAKE) run_all > benchmarks.txt 2>&1

clean:
	rm benchmarks.txt
	dune clean
