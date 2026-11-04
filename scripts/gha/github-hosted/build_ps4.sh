#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

# OO_PS4_TOOLCHAIN is set by deps_ps4.sh
export CC=clang-18
export CXX=clang++-18

WAF_CONFIGURE_OPTS="--ps4"
CMAKE_CONFIGURE_OPTS="-DCMAKE_TOOLCHAIN_FILE=cmake/PS4Toolchain.cmake"

source scripts/gha/build_common.sh
