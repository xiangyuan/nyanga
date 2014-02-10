
LIBDIR=./lib
DEPDIR=./deps

OS_NAME=$(shell uname -s)
MH_NAME=$(shell uname -m)

ifeq (${OS_NAME}, Darwin)
LPEG_BUILD=macosx
LIBEXT=dylib
else
LPEG_BUILD=linux
LIBEXT=so
endif


all: ${LIBDIR}/lpeg.so ${LIBDIR}/libczmq.${LIBEXT}

${LIBDIR}/lpeg.so:
	make -C ${DEPDIR}/lpeg ${LPEG_BUILD}
	cp ${DEPDIR}/lpeg/lpeg.so ${LIBDIR}

${LIBDIR}/libczmq.${LIBEXT}: ${LIBDIR}/libzmq.${LIBEXT}
	cd ${DEPDIR}/czmq && ./configure --with-libzmq-lib-dir=${DEPDIR}/zeromq/src/.libs --with-libzmq-include-dir=${DEPDIR}/zeromq/include && make 
	cp ${DEPDIR}/czmq/src/.libs/libczmq.${LIBEXT} ${LIBDIR}

${LIBDIR}/libzmq.${LIBEXT}:
	cd ${DEPDIR}/zeromq && ./configure && make 
	cp ${DEPDIR}/zeromq/src/.libs/libzmq.${LIBEXT} ${LIBDIR}

clean:
	make -C ${DEPDIR}/lpeg clean
	rm -f ${LIBDIR}/lpeg.so
	make -C ${DEPDIR}/czmq clean
	rm -f ${LIBDIR}/libczmq.${LIBEXT}
	make -C ${DEPDIR}/zeromq clean
	rm -f ${LIBDIR}/zeromq.${LIBEXT}


