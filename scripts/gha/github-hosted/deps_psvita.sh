#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

cd "$GITHUB_WORKSPACE" || exit 1

export VITASDK=/usr/local/vitasdk

# vdpm is a pacman frontend now, it asks for confirmation unless told otherwise
export VDPM_NONINTERACTIVE=1

# only the toolchain is needed for the SDK libraries, the engine deps
# (vitaGL, the SDL fork, vita-rtld) stay in xash3d-fwgs CI
git clone https://github.com/vitasdk/vdpm.git --depth=1 || exit 1
pushd vdpm || exit 1
./bootstrap-vitasdk.sh || exit 1
popd || exit 1

# for ccache, usually preinstalled on GitHub images
command -v ccache > /dev/null 2>&1 || sudo apt install -y ccache

# the vita compiler is specifically super slow, so caching helps a lot.
# hlsdk's xcompile.py calls the compilers by absolute path, which a PATH
# masquerade can't intercept: rename the real compilers and put ccache
# wrappers in their place instead
for tool in gcc g++; do
	compiler="$VITASDK/bin/arm-vita-eabi-$tool"
	sudo mv "$compiler" "$compiler.real" || exit 1
	printf '#!/bin/sh\nexec ccache "%s.real" "$@"\n' "$compiler" | sudo tee "$compiler" > /dev/null
	sudo chmod +x "$compiler" || exit 1
done

git clone --recursive https://github.com/FWGS/hlsdk-portable

wget "https://github.com/mikefarah/yq/releases/download/v$YQ_VERSION/yq_linux_amd64.tar.gz" -O- | tar -xzvf -
mv yq_linux_amd64 yq
