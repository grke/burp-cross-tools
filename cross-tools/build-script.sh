#!/usr/bin/env bash
#
# This is a heavily modified version of "MingGW-w64 Build Script 2.8.2"
# by Kyle Schwarz. Modified by Graham Keeling.

set -e
set -x

readonly WORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. "$WORK_DIR"/../functions.sh

readonly ver_binutils="2.29.1"
readonly ver_gcc="7.3.0"
readonly ver_gmp="6.1.2"
readonly ver_isl="0.18"
readonly ver_mingw="v5.0.3"
readonly ver_mpc="1.1.0"
readonly ver_mpfr="4.0.1"

readonly binutils="binutils-$ver_binutils.tar.xz"
readonly gcc="gcc-$ver_gcc.tar.xz"
readonly gmp="gmp-$ver_gmp.tar.xz"
readonly isl="isl-$ver_isl.tar.xz"
readonly mingw="mingw-w64-$ver_mingw.tar.bz2"
readonly mpc="mpc-$ver_mpc.tar.gz"
readonly mpfr="mpfr-$ver_mpfr.tar.xz"

maybe_download "$binutils" "https://ftp.gnu.org/gnu/binutils/$binutils"
maybe_download "$gcc"      "https://ftp.gnu.org/gnu/gcc/gcc-$ver_gcc/$gcc"
maybe_download "$gmp"      "https://ftp.gnu.org/gnu/gmp/$gmp"
maybe_download "$isl"      "http://isl.gforge.inria.fr/$isl"
maybe_download "$mingw"    "https://downloads.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release/$mingw"
maybe_download "$mpc"      "https://ftp.gnu.org/gnu/mpc/$mpc"
maybe_download "$mpfr"     "https://ftp.gnu.org/gnu/mpfr/$mpfr"

readonly uname_m="$(uname -m)"
readonly mingw_w64_i686_prefix="$WORK_DIR/mingw-w64-i686"
readonly mingw_w64_x86_64_prefix="$WORK_DIR/mingw-w64-x86_64"
readonly target_i686="i686-w64-mingw32"
readonly target_x86_64="x86_64-w64-mingw32"
readonly mpfr_prefix="$WORK_DIR/packages/gcc/packages/mpfr/mpfr-$ver_mpfr-$uname_m"
readonly mpc_prefix="$WORK_DIR/packages/gcc/packages/mpc/mpc-$ver_mpc-$uname_m"
readonly gmp_prefix="$WORK_DIR/packages/gcc/packages/gmp/gmp-$ver_gmp-$uname_m"

readonly cpu_count="$(cat /proc/cpuinfo | grep processor | wc -l)"
readonly build_type="$(sh $WORK_DIR/source/config.guess)"
[ -z "$build_type" ] && echo "no build_type" && exit 1

function clear_build() {
	cd ".."
	rm -frv "build"
	mkdir -p "build"
	cd "build"
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

	export PATH="$mingw_w64_prefix/bin:$PATH"
	rm -rf "$mingw_w64_prefix"

	extract "$binutils"

	clear_build
	"../source/binutils-$ver_binutils/configure" \
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

	clear_build
	rm -frv "headers" "crt"
	mkdir -p "headers" "crt"
	cd "headers"

	"../../source/mingw-w64-$ver_mingw/mingw-w64-headers/configure" \
		--build="$build_type" \
		--prefix="$mingw_w64_prefix/$mingw_w64_target" \
		--host="$mingw_w64_target" \
		--enable-sdk=all
	make install
	cd "$mingw_w64_prefix"
	ln -s "./$mingw_w64_target" "./mingw"

	cd "../packages/gcc"
	mkdir -p "build" "source" "packages"

	cd "source"
	extract "$gcc"
	cd "gcc-$ver_gcc"
	pwd
	patch -Np1 < ../../../../source/gcc.patch
	extract "$gmp" && mv "gmp-$ver_gmp" gmp
	extract "$isl" && mv "isl-$ver_isl" isl
	extract "$mpc" && mv "mpc-$ver_mpc" mpc
	extract "$mpfr" && mv "mpfr-$ver_mpfr" mpfr
	cd ..

	clear_build
	"../source/gcc-$ver_gcc/configure" \
		--build="$build_type" \
		--target="$mingw_w64_target" \
		--prefix="$mingw_w64_prefix" \
		--disable-multilib \
		--with-sysroot="$mingw_w64_prefix" \
		--with-host-libstdcxx="-lstdc++ -lsupc++" \
		--enable-languages="c,c++" \
		--enable-fully-dynamic-string
	make -j "$cpu_count" all-gcc
	make install-gcc

	cd "$WORK_DIR/packages/mingw64/build/crt"
	"../../source/mingw-w64-$ver_mingw/mingw-w64-crt/configure" \
		--build="$build_type" \
		--host="$mingw_w64_target" \
		--prefix="$mingw_w64_prefix/$mingw_w64_target" \
		--with-sysroot="$mingw_w64_prefix/$mingw_w64_target"
	make -j "$cpu_count"
	make install

	cd "$WORK_DIR/packages/gcc/build"
	make -j "$cpu_count"
	make install
}

orig_path="$PATH"
build_mingw_w64 "$target_i686" "$mingw_w64_i686_prefix"
export PATH="$orig_path"
build_mingw_w64 "$target_x86_64" "$mingw_w64_x86_64_prefix"
cd "$WORK_DIR"
rm -fr "build" "packages"
echo "MinGW-w64 has been built without errors."

exit 0
