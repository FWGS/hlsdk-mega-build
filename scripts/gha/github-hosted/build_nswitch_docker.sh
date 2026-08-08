#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Runs inside the devkitpro/devkita64 container, launched by build_nswitch.sh

# the workspace is owned by the runner user, not the container's root
git config --global --add safe.directory '*'

# build_common.sh calls `python waf` and packs with 7z, the image has neither
ln -sf /usr/bin/python3 /usr/bin/python
apt-get update || exit 1
apt-get install -y --no-install-recommends p7zip-full ccache || exit 1

# hlsdk's xcompile.py calls the compilers by absolute path, which a PATH
# masquerade can't intercept: rename the real compilers and put ccache
# wrappers in their place instead. DEVKITPRO comes from the image environment
for tool in gcc g++; do
	compiler="$DEVKITPRO/devkitA64/bin/aarch64-none-elf-$tool"
	mv "$compiler" "$compiler.real" || exit 1
	printf '#!/bin/sh\nexec ccache "%s.real" "$@"\n' "$compiler" > "$compiler"
	chmod +x "$compiler" || exit 1
done

WAF_CONFIGURE_OPTS="--nswitch"

source scripts/gha/build_common.sh
