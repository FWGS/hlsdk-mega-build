#!/bin/bash

# "booo, bash feature!"
declare -A ARCH_TRIPLET CROSS_COMPILE_CC CROSS_COMPILE_CXX
ARCH_TRIPLET[amd64]=x86_64-linux-gnu
ARCH_TRIPLET[i386]=i386-linux-gnu
ARCH_TRIPLET[arm64]=aarch64-linux-gnu
ARCH_TRIPLET[armhf]=arm-linux-gnueabihf
ARCH_TRIPLET[riscv64]=riscv64-linux-gnu
ARCH_TRIPLET[ppc64el]=powerpc64le-linux-gnu
CROSS_COMPILE_CC[amd64]=cc
CROSS_COMPILE_CC[i386]="cc -m32"
CROSS_COMPILE_CXX[amd64]=c++
CROSS_COMPILE_CXX[i386]="c++ -m32"
for i in arm64 armhf riscv64 ppc64el; do
	CROSS_COMPILE_CC[$i]=${ARCH_TRIPLET[$i]}-gcc
	CROSS_COMPILE_CXX[$i]=${ARCH_TRIPLET[$i]}-g++
done
export PKG_CONFIG_PATH=${ARCH_TRIPLET[$GH_CPU_ARCH]}
export CC=${CROSS_COMPILE_CC[$GH_CPU_ARCH]}
export CXX=${CROSS_COMPILE_CXX[$GH_CPU_ARCH]}

source scripts/gha/build_common.sh
