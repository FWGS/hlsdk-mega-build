#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

cd "$GITHUB_WORKSPACE" || exit 1

# the toolchain lives in the devkitPro container, see build_nswitch.sh.
# libsolder is only needed by the engine, not by the SDK libraries
docker pull devkitpro/devkita64:latest || exit 1

# the build itself caches inside the container, but the workflow's ccache
# statistics step runs on the host. Usually preinstalled on GitHub images
command -v ccache > /dev/null 2>&1 || sudo apt install -y ccache

git clone --recursive https://github.com/FWGS/hlsdk-portable

wget "https://github.com/mikefarah/yq/releases/download/v$YQ_VERSION/yq_linux_amd64.tar.gz" -O- | tar -xzvf -
mv yq_linux_amd64 yq
