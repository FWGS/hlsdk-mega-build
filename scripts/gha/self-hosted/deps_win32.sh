#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

cd "$GITHUB_WORKSPACE" || exit 1

git clone --recursive https://github.com/FWGS/hlsdk-portable
