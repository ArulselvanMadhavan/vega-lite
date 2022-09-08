
all:
	@dune build @all

test:
	@dune runtest --force

clean:
	@dune clean

WATCH ?= @all
watch:
	@dune build $(WATCH) -w

format:
	@dune build @fmt --auto-promote

init:
	mkdir -p outputs

demo: init
	@dune exec demo

vit: init
	@dune exec vit

layer: init
	@dune exec layer
