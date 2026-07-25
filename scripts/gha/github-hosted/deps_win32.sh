#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

git clone --recursive https://github.com/FWGS/hlsdk-portable

curl -L "https://github.com/mikefarah/yq/releases/download/v4.44.6/yq_windows_amd64.exe" -o yq.exe
