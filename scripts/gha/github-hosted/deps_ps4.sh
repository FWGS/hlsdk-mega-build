#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

cd "$GITHUB_WORKSPACE" || exit 1

# OpenOrbis libraries are built with LLVM 18, newer versions don't work
sudo apt update || exit 2
sudo apt install -y clang-18 lld-18 llvm-18 || exit 2

# OpenOrbis toolchain, same release as xash3d-fwgs CI uses
OO_URL=https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain/releases/download/v0.5.4/toolchain-llvm-18.tar.gz
OO_SHA256=3c7cd5bb593ca74fa1c13fd59f3938dc0fc07985167f7275063019e63abe4526

curl -L -o oo.tar.gz "$OO_URL" || exit 1
echo "$OO_SHA256  oo.tar.gz" | sha256sum -c - || exit 1
rm -rf oo && mkdir oo || exit 1
tar -xzf oo.tar.gz -C oo || exit 1
rm oo.tar.gz

OO_LINKER=$(find oo -maxdepth 4 -name link.x | head -n 1)
[ -n "$OO_LINKER" ] || exit 1

echo "OO_PS4_TOOLCHAIN=$GITHUB_WORKSPACE/$(dirname "$OO_LINKER")" >> "$GITHUB_ENV"

# for ccache statistics step, usually preinstalled on GitHub images
command -v ccache > /dev/null 2>&1 || sudo apt install -y ccache

git clone --recursive https://github.com/FWGS/hlsdk-portable

wget "https://github.com/mikefarah/yq/releases/download/v$YQ_VERSION/yq_linux_amd64.tar.gz" -O- | tar -xzvf -
mv yq_linux_amd64 yq
