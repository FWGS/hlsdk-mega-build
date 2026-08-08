#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

git clone --recursive https://github.com/FWGS/hlsdk-portable

curl -L "https://github.com/mikefarah/yq/releases/download/v$YQ_VERSION/yq_windows_amd64.exe" -o yq.exe

# ccache supports MSVC well enough for /Zi-less release builds
choco install ccache -y --no-progress
