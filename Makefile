
LIBDIR=./lib
CURDIR = $(shell pwd)
DEPDIR = ${CURDIR}/deps
BUILD  = ${CURDIR}/build

LDFLAGS=

OS_NAME=$(shell uname -s)
MH_NAME=$(shell uname -m)

ifeq (${OS_NAME}, Darwin)
LPEG_BUILD=macosx
LIBEXT=dylib
LDFLAGS=-lluajit -lstdc++ -Wl,-all_load
else
LPEG_BUILD=linux
LIBEXT=so
LDFLAGS=-lluajit -lstdc++ -Wl,--whole-archive -Wl,-E
endif

DEPS = ${BUILD}/lib/libnyanga.a ${BUILD}/lib/liblpeg.a ${BUILD}/lib/libzmq.a ${BUILD}/lib/libczmq.a

all: nyanga.so

nyanga.so: ${DEPS}
	${CC} -dynamic -bundle -undefined dynamic_lookup -o nyanga.so -L../luajit-2.0/src/ ${LDFLAGS} ${DEPS}

${BUILD}/lib/libnyanga.a:
	mkdir -p ${BUILD}/lib
	mkdir -p ${BUILD}/nyanga
	luajit -b -n "nyanga" lib/nyanga.lua ${BUILD}/nyanga/init.o
	luajit -b -n "nyanga.re" lib/nyanga/re.lua ${BUILD}/nyanga/re.o
	luajit -b -n "nyanga.runtime" lib/nyanga/runtime.lua ${BUILD}/nyanga/runtime.o
	luajit -b -n "nyanga.parser" lib/nyanga/parser.lua ${BUILD}/nyanga/parser.o
	luajit -b -n "nyanga.parser.defs" lib/nyanga/parser/defs.lua ${BUILD}/nyanga/parser_defs.o
	luajit -b -n "nyanga.syntax" lib/nyanga/syntax.lua ${BUILD}/nyanga/syntax.o
	luajit -b -n "nyanga.compiler" lib/nyanga/compiler.lua ${BUILD}/nyanga/compiler.o
	luajit -b -n "nyanga.transformer" lib/nyanga/transformer.lua ${BUILD}/nyanga/transformer.o
	luajit -b -n "nyanga.bytecode" lib/nyanga/bytecode.lua ${BUILD}/nyanga/bytecode.o
	luajit -b -n "nyanga.builder" lib/nyanga/builder.lua ${BUILD}/nyanga/builder.o
	luajit -b -n "nyanga.util" lib/nyanga/util.lua ${BUILD}/nyanga/util.o
	luajit -b -n "nyanga.generator" lib/nyanga/generator.lua ${BUILD}/nyanga/generator.o
	luajit -b -n "nyanga.generator.source" lib/nyanga/generator/source.lua ${BUILD}/nyanga/generator_source.o
	luajit -b -n "nyanga.generator.bytecode" lib/nyanga/generator/bytecode.lua ${BUILD}/nyanga/generator_bytecode.o
	ar rcus ${BUILD}/lib/libnyanga.a ${BUILD}/nyanga/*.o

${BUILD}/lib/liblpeg.a:
	make -C ${DEPDIR}/lpeg ${LPEG_BUILD}
	ar rcus ${BUILD}/lib/liblpeg.a ${DEPDIR}/lpeg/*.o

${BUILD}/lib/libczmq.a: ${BUILD}/lib/libzmq.a
	cd ${DEPDIR}/czmq && ./configure --enable-static --with-libzmq=${BUILD} --prefix=${BUILD} && make && make install

${BUILD}/lib/libzmq.a:
	cd ${DEPDIR}/zeromq && ./configure --enable-static --prefix=${BUILD} && make && make install

clean:
	make -C ${DEPDIR}/lpeg clean
	make -C ${DEPDIR}/czmq clean
	make -C ${DEPDIR}/zeromq clean
	rm -rf ${BUILD}
	rm -f nyanga.so


