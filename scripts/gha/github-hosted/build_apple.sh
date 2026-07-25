#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

# transparently route compilers through ccache
if command -v brew > /dev/null 2>&1 && [ -d "$(brew --prefix)/opt/ccache/libexec" ]; then
	export PATH="$(brew --prefix)/opt/ccache/libexec:$PATH"
fi

source scripts/gha/build_common.sh
