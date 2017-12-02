#!/usr/bin/env bash
#
# This is a heavily modified version of "MingGW-w64 Build Script 2.8.2"
# by Kyle Schwarz. Modified by Graham Keeling.

set -e

readonly WORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. "$WORK_DIR"/../functions.sh

readonly binutils_ver="2.24"
readonly gcc_ver="4.7.4"
readonly gmp_ver="6.0.0"
readonly mingw_ver="v2.0.9"
readonly mpc_ver="1.0.2"
readonly mpfr_ver="3.1.2"

readonly binutils="binutils-$binutils_ver.tar.bz2"
readonly gcc="gcc-$gcc_ver.tar.bz2"
readonly gmp="gmp-${gmp_ver}a.tar.bz2"
readonly mingw="mingw-w64-$mingw_ver.tar.gz"
readonly mpc="mpc-$mpc_ver.tar.gz"
readonly mpfr="mpfr-$mpfr_ver.tar.bz2"

maybe_download "$binutils" "https://ftp.gnu.org/gnu/binutils"
maybe_download "$gcc"      "https://ftp.gnu.org/gnu/gcc/gcc-$gcc_ver"
maybe_download "$gmp"      "https://ftp.gnu.org/gnu/gmp"
maybe_download "$mingw"    "https://downloads.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release"
maybe_download "$mpc"      "https://ftp.gnu.org/gnu/mpc"
maybe_download "$mpfr"     "https://ftp.gnu.org/gnu/mpfr"

readonly uname_m="$(uname -m)"
readonly mingw_w64_i686_prefix="$WORK_DIR/mingw-w64-i686"
readonly mingw_w64_x86_64_prefix="$WORK_DIR/mingw-w64-x86_64"
readonly target_i686="i686-w64-mingw32"
readonly target_x86_64="x86_64-w64-mingw32"
readonly mpfr_prefix="$WORK_DIR/packages/gcc/packages/mpfr/mpfr-$mpfr_ver-$uname_m"
readonly mpc_prefix="$WORK_DIR/packages/gcc/packages/mpc/mpc-$mpc_ver-$uname_m"
readonly gmp_prefix="$WORK_DIR/packages/gcc/packages/gmp/gmp-$gmp_ver-$uname_m"

readonly cpu_count="$(cat /proc/cpuinfo | grep processor | wc -l)"
readonly build_type="$(sh $WORK_DIR/source/config.guess)"
[ -z "$build_type" ] && echo "no build_type" && exit 1

function clear_build() {
	cd ".."
	rm -frv "build"
	mkdir -p "build"
	cd "build"
}

function build_gmp() {
	cd "gmp"
	mkdir -p "build" "source"
	cd "source"
	extract "$gmp"
	if [[ ! -d "$gmp_prefix" ]]; then
	    clear_build
	    CC=gcc "../source/gmp-$gmp_ver/configure" \
		--build="$build_type" \
		--prefix="$gmp_prefix" \
		--disable-shared \
		--enable-static \
		--enable-cxx \
		CPPFLAGS=-fexceptions
	    make -j "$cpu_count"
	    make install
	fi
}

function build_mpfr() {
	cd "../../mpfr"
	mkdir -p "build" "source"
	cd "source"
	extract "$mpfr"
	if [[ ! -d "$mpfr_prefix" ]]; then
	    clear_build
	    CC=gcc "../source/mpfr-$mpfr_ver/configure" \
			--build="$build_type" \
			--prefix="$mpfr_prefix" \
			--disable-shared \
			--enable-static \
			--with-gmp="$gmp_prefix"
	    make -j "$cpu_count"
	    make install
	fi
}

function build_mpc() {
	cd "../../mpc"
	mkdir -p "build" "source"
	cd "source"
	extract "$mpc"
	if [[ ! -d "$mpc_prefix" ]]; then
	    clear_build
	    CC=gcc "../source/mpc-$mpc_ver/configure" \
		--build="$build_type" \
		--prefix="$mpc_prefix" \
		--with-gmp="$gmp_prefix" \
		--with-mpfr="$mpfr_prefix" \
		--disable-shared \
		--enable-static
	    make -j "$cpu_count"
	    make install
	fi
}

function build_mingw_w64() {
	local mingw_w64_target=$1
	local mingw_w64_prefix=$2
	shift 2
	cd "$WORK_DIR"
	rm -frv "$mingw_w64_prefix"
	rm -rf packages
	mkdir -p packages
	cd "packages"
	mkdir -p "binutils" "gcc"
	cd "binutils"
	mkdir -p "build" "source"
	cd "source"

	extract "$binutils"

	clear_build
	CC=gcc "../source/binutils-$binutils_ver/configure" \
		--build="$build_type" \
		--target="$mingw_w64_target" \
		--prefix="$mingw_w64_prefix" \
		--disable-multilib \
		--with-sysroot="$mingw_w64_prefix"
	make -j "$cpu_count"
	make install

	cd "$WORK_DIR"
	mkdir -p packages/mingw64
	cd packages/mingw64
	mkdir -p build source
	cd source

	extract "$mingw"

	export PATH="$PATH:$mingw_w64_prefix/bin"
	clear_build
	rm -frv "headers" "crt"
	mkdir -p "headers" "crt"
	cd "headers"

	"../../source/mingw-w64-$mingw_ver/mingw-w64-headers/configure" \
		--build="$build_type" \
		--prefix="$mingw_w64_prefix" \
		--host="$mingw_w64_target" \
		--enable-sdk=all
	make install
	cd "$mingw_w64_prefix"
	ln -s "./$mingw_w64_target" "./mingw"
	cd "../packages/gcc"
	mkdir -p "build" "source" "packages"
	cd "packages"
	mkdir -p "gmp" "mpfr" "mpc"

	build_gmp
	build_mpfr
	build_mpc

	# Build GCC (gcc only)
	cd "../../../source"
	extract "$gcc"

	clear_build
	CC=gcc LDFLAGS="-L$gmp_prefix/lib" "../source/gcc-$gcc_ver/configure" \
		--build="$build_type" \
		--target="$mingw_w64_target" \
		--prefix="$mingw_w64_prefix" \
		--disable-multilib \
		--with-sysroot="$mingw_w64_prefix" \
		--with-mpc="$mpc_prefix" \
		--with-mpfr="$mpfr_prefix" \
		--with-gmp="$gmp_prefix" \
		--with-host-libstdcxx="-lstdc++ -lsupc++" \
		--enable-languages="c,c++," \
		--enable-fully-dynamic-string
	make -j "$cpu_count" all-gcc
	make install-gcc

	# Build mingw-w64 CRT
	cd "$WORK_DIR/packages/mingw64/build/crt"
	"../../source/mingw-w64-$mingw_ver/mingw-w64-crt/configure" \
		--build="$build_type" \
		--host="$mingw_w64_target" \
		--prefix="$mingw_w64_prefix" \
		--with-sysroot="$mingw_w64_prefix"
	make -j "$cpu_count"
	make install

	# Build GCC
	cd "$WORK_DIR/packages/gcc/build"
	make -j "$cpu_count"
	make install
}

build_mingw_w64 "$target_i686" "$mingw_w64_i686_prefix"
build_mingw_w64 "$target_x86_64" "$mingw_w64_x86_64_prefix"
cd "$WORK_DIR"
rm -fr "build" "packages"
echo "MinGW-w64 has been built without errors."

exit 0
