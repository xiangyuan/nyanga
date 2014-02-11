
LIBDIR =./lib
CURDIR = $(shell pwd)
DEPDIR = ${CURDIR}/deps
BUILD  = ${CURDIR}/build

LJ = ${DEPDIR}/luajit/src/luajit
LJC = ${LJ} -b -g
NGC = boot/bin/ngac

CFLAGS=-O2 -Wall
LDFLAGS=-lm -ldl
SOFLAGS=

OS_NAME=$(shell uname -s)
MH_NAME=$(shell uname -m)

ifeq (${OS_NAME}, Darwin)
LPEG_BUILD=macosx
LIBEXT=dylib
LDFLAGS+=-lstdc++ -Wl,-all_load
SOFLAGS+=-dynamic -bundle -undefined dynamic_lookup
ifeq (${MH_NAME}, x86_64)
CFLAGS+=-pagezero_size 10000 -image_base 100000000
endif
else
LPEG_BUILD=linux
LIBEXT=so
LDFLAGS+=-lstdc++ -Wl,--whole-archive -Wl,-E
SOFLAGS+=-shared -fPIC
endif

LPEG := boot/lib/lpeg.so

DEPS := ${BUILD}/deps/liblpeg.a \
	${BUILD}/deps/libzmq.a \
	${BUILD}/deps/libczmq.a \
	${BUILD}/deps/libluajit.a

CORE := ${BUILD}/core/init.o \
	${BUILD}/core/zmq.o \
	${BUILD}/core/queue.o \
	${BUILD}/core/fiber.o \
	${BUILD}/core/loop.o \
	${BUILD}/core/async.o \
	${BUILD}/core/ffi.o \
	${BUILD}/core/ffi_posix.o \
	${BUILD}/core/ffi_osx.o \
	${BUILD}/core/ffi_linux.o \
	${BUILD}/core/ffi_bsd.o \
	${BUILD}/core/ffi_zmq.o

LANG := ${BUILD}/lang/builder.o \
	${BUILD}/lang/bytecode.o \
	${BUILD}/lang/compiler.o \
	${BUILD}/lang/generator.o \
	${BUILD}/lang/init.o \
	${BUILD}/lang/tree.o \
	${BUILD}/lang/parser.o \
	${BUILD}/lang/re.o \
	${BUILD}/lang/syntax.o \
	${BUILD}/lang/transformer.o \
	${BUILD}/lang/util.o


LIBS := ${BUILD}/nyanga.so

EXEC := ${BUILD}/nyanga

all: dirs ${LJ} ${LIBS} ${EXEC}

dirs:
	mkdir -p ${BUILD}/deps
	mkdir -p ${BUILD}/lang
	mkdir -p ${BUILD}/core

${BUILD}/nyanga: ${LJ} ${LPEG} ${DEPS}
	${CC} ${CFLAGS} -I${DEPDIR}/luajit/src -L${DEPDIR}/luajit/src -o ${BUILD}/nyanga src/nyanga.c ${DEPS} ${LDFLAGS}

${BUILD}/nyanga.so: ${BUILD}/deps/liblpeg.a ${BUILD}/lang.a ${BUILD}/core.a ${BUILD}/main.o
	${CC} ${SOFLAGS} -o ${BUILD}/nyanga.so ${LDFLAGS} ${BUILD}/main.o ${BUILD}/deps/liblpeg.a ${BUILD}/lang.a ${BUILD}/core.a

${BUILD}/lang.a: ${LJ}
	mkdir -p ${BUILD}/lang
	${LJC} -n "nyanga.lang" src/lang/init.lua ${BUILD}/lang/init.o
	${LJC} -n "nyanga.lang.re" src/lang/re.lua ${BUILD}/lang/re.o
	${LJC} -n "nyanga.lang.parser" src/lang/parser.lua ${BUILD}/lang/parser.o
	${LJC} -n "nyanga.lang.tree" src/lang/tree.lua ${BUILD}/lang/tree.o
	${LJC} -n "nyanga.lang.syntax" src/lang/syntax.lua ${BUILD}/lang/syntax.o
	${LJC} -n "nyanga.lang.compiler" src/lang/compiler.lua ${BUILD}/lang/compiler.o
	${LJC} -n "nyanga.lang.transformer" src/lang/transformer.lua ${BUILD}/lang/transformer.o
	${LJC} -n "nyanga.lang.bytecode" src/lang/bytecode.lua ${BUILD}/lang/bytecode.o
	${LJC} -n "nyanga.lang.builder" src/lang/builder.lua ${BUILD}/lang/builder.o
	${LJC} -n "nyanga.lang.util" src/lang/util.lua ${BUILD}/lang/util.o
	${LJC} -n "nyanga.lang.generator" src/lang/generator.lua ${BUILD}/lang/generator.o
	ar rcus ${BUILD}/lang.a ${BUILD}/lang/*.o

${BUILD}/main.o:
	${LJC} -n "nyanga" src/main.lua ${BUILD}/main.o

${BUILD}/core.a: ${CORE}
	ar rcus ${BUILD}/core.a ${BUILD}/core/*.o

${BUILD}/core/init.o:
	${LJC} -n "nyanga.core" src/core/init.lua ${BUILD}/core/init.o

${BUILD}/core/zmq.o:
	${NGC} -n "nyanga.core.zmq" src/core/zmq.nga ${BUILD}/core/zmq.o

${BUILD}/core/queue.o:
	${NGC} -n "nyanga.core.queue" src/core/queue.nga ${BUILD}/core/queue.o

${BUILD}/core/fiber.o:
	${NGC} -n "nyanga.core.fiber" src/core/fiber.nga ${BUILD}/core/fiber.o

${BUILD}/core/loop.o:
	${NGC} -n "nyanga.core.loop" src/core/loop.nga ${BUILD}/core/loop.o

${BUILD}/core/async.o:
	${NGC} -n "nyanga.core.async" src/core/async.nga ${BUILD}/core/async.o

${BUILD}/core/ffi.o:
	${NGC} -n "nyanga.core.ffi" src/core/ffi/init.nga ${BUILD}/core/ffi.o

${BUILD}/core/ffi_posix.o:
	${NGC} -n "nyanga.core.ffi.posix" src/core/ffi/posix.nga ${BUILD}/core/ffi_posix.o

${BUILD}/core/ffi_osx.o:
	${NGC} -n "nyanga.core.ffi.osx" src/core/ffi/osx.nga ${BUILD}/core/ffi_osx.o

${BUILD}/core/ffi_linux.o:
	${NGC} -n "nyanga.core.ffi.linux" src/core/ffi/linux.nga ${BUILD}/core/ffi_linux.o

${BUILD}/core/ffi_bsd.o:
	${NGC} -n "nyanga.core.ffi.bsd" src/core/ffi/bsd.nga ${BUILD}/core/ffi_bsd.o

${BUILD}/core/ffi_zmq.o:
	${NGC} -n "nyanga.core.ffi.zmq" src/core/ffi/zmq.nga ${BUILD}/core/ffi_zmq.o

${BUILD}/deps/liblpeg.a: ${LPEG}
	ar rcus ${BUILD}/deps/liblpeg.a ${DEPDIR}/lpeg/*.o

${BUILD}/deps/libczmq.a: ${BUILD}/deps/libzmq.a
	cd ${DEPDIR}/czmq && ./configure --with-libzmq=${BUILD}/deps --prefix=${BUILD}/deps && make && make install
	cp ${BUILD}/deps/lib/libczmq.a ${BUILD}/deps

${BUILD}/deps/libzmq.a:
	cd ${DEPDIR}/zeromq && ./configure --prefix=${BUILD}/deps && make && make install
	cp ${BUILD}/deps/lib/libzmq.a ${BUILD}/deps

${BUILD}/deps/libluajit.a: ${LJ}
	cp ${DEPDIR}/luajit/src/libluajit.a ${BUILD}/deps/libluajit.a

${LJ}:
	git submodule update --init ${DEPDIR}/luajit
	${MAKE} XCFLAGS="-DLUAJIT_ENABLE_LUA52COMPAT" -C ${DEPDIR}/luajit

${LPEG}:
	make -C ${DEPDIR}/lpeg ${LPEG_BUILD}
	cp ${DEPDIR}/lpeg/lpeg.so boot/lib/

clean:
	rm -rf ${BUILD}/core/*
	rm -rf ${BUILD}/lang/*
	rm -f ${BUILD}/core.a
	rm -f ${BUILD}/lang.a
	rm -f ${BUILD}/main.o
	rm -f ${BUILD}/nyanga.so
	rm -f ${BUILD}/nyanga

realclean: clean
	make -C ${DEPDIR}/luajit clean
	make -C ${DEPDIR}/lpeg clean
	make -C ${DEPDIR}/czmq clean
	make -C ${DEPDIR}/zeromq clean
	rm -rf ${BUILD}

bootstrap: ${LJ} ${LPEG}
	mkdir -p boot/bin
	mkdir -p boot/lib
	mkdir -p boot/src/nyanga/lang
	${LJC} src/lang/re.lua          boot/src/nyanga/lang/re.raw
	${LJC} src/lang/parser.lua      boot/src/nyanga/lang/parser.raw
	${LJC} src/lang/tree.lua        boot/src/nyanga/lang/tree.raw
	${LJC} src/lang/syntax.lua      boot/src/nyanga/lang/syntax.raw
	${LJC} src/lang/compiler.lua    boot/src/nyanga/lang/compiler.raw
	${LJC} src/lang/transformer.lua boot/src/nyanga/lang/transformer.raw
	${LJC} src/lang/bytecode.lua    boot/src/nyanga/lang/bytecode.raw
	${LJC} src/lang/builder.lua     boot/src/nyanga/lang/builder.raw
	${LJC} src/lang/util.lua        boot/src/nyanga/lang/util.raw
	${LJC} src/lang/generator.lua   boot/src/nyanga/lang/generator.raw
	${LJC} src/lang/gensource.lua   boot/src/nyanga/lang/gensource.raw

.PHONY: all clean realclean bootstrap

