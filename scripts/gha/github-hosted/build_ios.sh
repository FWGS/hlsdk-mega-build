#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

# transparently route compilers through ccache
if command -v brew > /dev/null 2>&1 && [ -d "$(brew --prefix)/opt/ccache/libexec" ]; then
	export PATH="$(brew --prefix)/opt/ccache/libexec:$PATH"
fi

USE_CMAKE=1
CMAKE_CONFIGURE_OPTS="-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0"

source scripts/gha/build_common.sh
