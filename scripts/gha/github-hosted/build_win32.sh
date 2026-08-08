#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

# waf has potential troubles prepending ccache to cl.exe, so force cmake for now 
USE_CMAKE=1

# tolerate trees with ancient cmake_minimum_required against modern cmake
# enable /Z7 debug info, so it can be cached with ccache (the only case supported by ccache)
# /debug linker flag will still collect it into PDB at link time
# the format abstraction sits behind CMP0141, forced NEW so old trees get it
CMAKE_CONFIGURE_OPTS="-DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_POLICY_DEFAULT_CMP0141=NEW -DCMAKE_MSVC_DEBUG_INFORMATION_FORMAT=Embedded"

source scripts/gha/build_common.sh
