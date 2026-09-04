#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

wget "https://github.com/mikefarah/yq/releases/download/v$YQ_VERSION/yq_darwin_arm64.tar.gz" -O- | tar -xzvf -
mv yq_darwin_arm64 yq
chmod +x yq

git clone --recursive https://github.com/FWGS/hlsdk-portable

# ccache for faster rebuilds, PATH masquerade is set up in build_apple.sh
command -v ccache > /dev/null 2>&1 || brew install ccache
