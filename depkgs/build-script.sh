#!/usr/bin/env bash

set -e

WORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. "$WORK_DIR"/../functions.sh

readonly CROSS="$WORK_DIR"/../cross-tools
readonly SRCDIR="$WORK_DIR"/source
readonly ORIGPATH=$PATH

readonly check_ver=0.10.0
readonly librsync_ver=2.0.2
readonly nsis_ver=2.46
readonly openssl_ver=1.1.1k
readonly pcre_ver=8.45
readonly scons_ver=2.3.5
readonly stab2cv_ver=0.1
readonly yajl_ver=2.1.0
readonly zlib_ver=1.2.11

readonly check="check-$check_ver.tar.gz"
readonly librsync="librsync-$librsync_ver.tar.gz"
readonly nsis_src="nsis-$nsis_ver-src.tar.bz2"
readonly nsis_zip="nsis-$nsis_ver.zip"
readonly openssl="openssl-$openssl_ver.tar.gz"
readonly pcre="pcre-$pcre_ver.tar.bz2"
readonly scons="scons-$scons_ver.tar.gz"
readonly stab2cv="stab2cv-$stab2cv_ver.tar.bz2"
readonly yajl="lloyd-yajl-$yajl_ver-ga0ecdde.tar.gz"
readonly zlib="zlib-$zlib_ver.tar.gz"

maybe_download "$check"     "http://downloads.sourceforge.net/check/$check"
maybe_download "$librsync"  "https://github.com/librsync/librsync/archive/v$librsync_ver.tar.gz"
maybe_download "$nsis_src"  "https://downloads.sourceforge.net/project/nsis/NSIS%202/$nsis_ver/$nsis_src"
maybe_download "$nsis_zip"  "https://downloads.sourceforge.net/project/nsis/NSIS%202/$nsis_ver/$nsis_zip"
maybe_download "$openssl"   "https://www.openssl.org/source/$openssl"
maybe_download "$pcre"      "https://ftp.pcre.org/pub/pcre/$pcre"
maybe_download "$scons"     "https://downloads.sourceforge.net/project/scons/scons/$scons_ver/$scons"
maybe_download "$stab2cv"   "http://downloads.sourceforge.net/sourceforge/stab2cv/$stab2cv"
maybe_download "$yajl"      "http://github.com/lloyd/yajl/tarball/$yajl_ver"
maybe_download "$zlib"      "http://zlib.net/$zlib"

function apply_patches() {
	local name="$1"
	for i in "$SRCDIR/$name"-patches/*.patch ; do
		patch -Np1 < "$i"
	done
}

function cleanup() {
	local name="$1"
	cd "$SRCDIR"
	rm -rf "$name"
}

function do_build() {
	TGT="$1"
	HOST="$2"
	SSLSUFFIX="$3"
	DEPKGS="$WORK_DIR/$TGT"
	if [ -z "$TGT" -o -z "$HOST" ] ; then
		echo "do_build called with not enough parameters"
		fail
	fi
	COMPPREFIX="$CROSS/$TGT/bin/$HOST"-
	BINARY_PATH="$DEPKGS/bin"
	INCLUDE_PATH="$DEPKGS/include"
	LIBRARY_PATH="$DEPKGS/lib"
	MAN_PATH="$DEPKGS/man"
	PATH="$CROSS/$TGT"/bin:$ORIGPATH

	rm -rf "$DEPKGS"
	mkdir -p "$BINARY_PATH"
	mkdir -p "$LIBRARY_PATH"
	mkdir -p "$INCLUDE_PATH"
	mkdir -p "$MAN_PATH"

	cp -v "$SRCDIR"/uthash.h "$INCLUDE_PATH"

	echo "unpack vss"
	cd "$DEPKGS"
	tar -zxf "$SRCDIR/vss.tar.gz"
	cd "vss"
	# Seems that the vss directory from Microsoft used to have upper case
	# components, but now has lower case. Do some conversion, just in case.
	find -type d | while read d ; do
		l=$(echo "$d" | tr '[:upper:]' '[:lower:]')
		[ "$d" != "$l" ] || continue
		mv "$d" "$l"
	done
	apply_patches vss

	echo "build check"
	cd "$SRCDIR"
	cleanup "check-$check_ver"
	extract "$check"
	cd "check-$check_ver"
	./configure CC_FOR_BUILD=gcc \
		CXX_FOR_BUILD=g++ \
		--host="$HOST" \
		--prefix="$DEPKGS"
	make PREFIX="$DEPKGS" install
	cleanup "check-$check_ver"

	echo "build yajl"
	cd "$SRCDIR"
	cleanup "lloyd-yajl-66cb08c"
	extract "$yajl"
	cd "lloyd-yajl-66cb08c"
	apply_patches yajl
	sed -i -e "s#BURP_COMPILER_PREFIX#$COMPPREFIX#g" "$TGT.cmake"
	sed -i -e "s#BURP_DEPKGS#$DEPKGS#g" "$TGT.cmake"
	TOOLCHAIN_FILE_PATH="$TGT.cmake" ./configure -p "$DEPKGS"
	make distro
	make install
	cp "$LIBRARY_PATH"/libyajl.dll "$BINARY_PATH"
	cleanup "lloyd-yajl-66cb08c"

	echo "build zlib"
	cd "$SRCDIR"
	cleanup "zlib-$zlib_ver"
	extract "$zlib"
	cd "zlib-$zlib_ver"
	make -f win32/Makefile.gcc PREFIX="$COMPPREFIX" all
	make -f win32/Makefile.gcc PREFIX="$COMPPREFIX" \
		INCLUDE_PATH="$INCLUDE_PATH" \
		LIBRARY_PATH="$LIBRARY_PATH" \
		BINARY_PATH="$BINARY_PATH" \
		SHARED_MODE=1 \
		install
	cleanup "zlib-$zlib_ver"

	echo "build pcre"
	cd "$SRCDIR"
	cleanup "pcre-$pcre_ver"
	extract "$pcre"
	cd "pcre-$pcre_ver"
	./configure CC_FOR_BUILD=gcc \
		CXX_FOR_BUILD=g++ \
		--host="$HOST" \
		--prefix="$DEPKGS" \
		--enable-utf8 \
		--enable-unicode-properties
	make PREFIX="$DEPKGS" all
	make PREFIX="$DEPKGS" install
	cleanup "pcre-$pcre_ver"

	echo "build stab2cv"
	cd "$SRCDIR"
	cleanup "stab2cv-$stab2cv"
	extract "$stab2cv"
	cd "stab2cv-$stab2cv_ver"
	./configure --prefix="$DEPKGS"/tools
	# No idea why this is now necessary for me.
	# Maybe it is because I am using a different version of
	# autoconf/automake than before?
	echo "#include <sys/types.h>" >> src/PEExecutable.h
	echo "#include <unistd.h>" >> src/PEExecutable.h
	make
	make install
	cleanup "stab2cv-$stab2cv_ver"

	echo "install scons"
	cd "$SRCDIR"
	cleanup "scons-$scons_ver"
	extract "$scons"
	cd "scons-$scons_ver"
	apply_patches scons
	python2 setup.py install --prefix="$DEPKGS"/scons
	cleanup "scons-$scons_ver"

	echo "build nsis"
	cd "$SRCDIR"
	cleanup "nsis-$nsis_ver"
	extract "$nsis_zip"
	rm -rf "$DEPKGS"/nsis
	mv "nsis-$nsis_ver" "$DEPKGS"/nsis
	cd "$SRCDIR"
	cleanup "nsis-$nsis_ver-src"
	extract "$nsis_src"
	cd "nsis-$nsis_ver-src"
	apply_patches nsis
	"$DEPKGS"/scons/bin/scons SKIPSTUBS=all SKIPPLUGINS=all \
		SKIPUTILS=all SKIPMISC=all NSIS_CONFIG_LOG=yes \
		XGCC_W32_PREFIX="$COMPPREFIX" \
		PREFIX="$DEPKGS"/nsis PREFIX_BIN="$DEPKGS"/nsis/Bin \
		PREFIX_CONF="$DEPKGS"/nsis PREFIX_DATA="$DEPKGS"/nsis \
		PREFIX_DOC="$DEPKGS"/nsis/Docs
	cp -p build/release/makensis/makensis "$DEPKGS"/nsis
	cleanup "nsis-$nsis_ver-src"

	echo "build openssl"
	cd "$SRCDIR"
	cleanup "openssl-$openssl_ver"
	extract "$openssl"
	cd "openssl-$openssl_ver"
	./Configure --prefix="$DEPKGS" \
		shared zlib-dynamic \
		threads \
		--with-zlib-include="$INCLUDE_PATH" \
		--cross-compile-prefix="$COMPPREFIX" "$SSLSUFFIX"
	make all
	make install_sw
	cleanup "openssl-$openssl_ver"

	echo "build librsync $librsync_ver"
	cd "$SRCDIR"
	cleanup "librsync-$librsync_ver"
	extract "$librsync"
	cd "librsync-$librsync_ver"
	apply_patches librsync

	# Changing compiler paths on the fly here
	sed "s#\[CROSS-TOOLS-PATH\]#${CROSS}#g" ${SRCDIR}/librsync-patches/toolchain.cmake > ${SRCDIR}/librsync-patches/toolchain_temp.cmake
	sed -i "s#\[TARGET-ARCH\]#${TGT}#g" ${SRCDIR}/librsync-patches/toolchain_temp.cmake
	sed -i "s#\[HOST-ARCH\]#${HOST}#g" ${SRCDIR}/librsync-patches/toolchain_temp.cmake

	cmake -DBUILD_RDIFF=OFF -DCMAKE_INSTALL_PREFIX="$DEPKGS" -DCMAKE_PREFIX_PATH="$DEPKGS" -DCMAKE_INSTALL_LIBDIR="$LIBRARY_PATH" -DENABLE_COMPRESSION=OFF -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_DISABLE_FIND_PACKAGE_POPT=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_libb2=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_BZip2=TRUE \
		-DCMAKE_DISABLE_FIND_PACKAGE_Doxygen=TRUE \
		-DCMAKE_TOOLCHAIN_FILE=${SRCDIR}/librsync-patches/toolchain_temp.cmake
	make
	make install
	cleanup "librsync-$librsync_ver"

	echo "Finished OK"
}

#do_build mingw-w64-i686 i686-w64-mingw32 mingw
do_build mingw-w64-x86_64 x86_64-w64-mingw32 mingw64
