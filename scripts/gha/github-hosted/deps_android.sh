#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

cd "$GITHUB_WORKSPACE" || exit 1

wget https://dl.google.com/android/repository/android-ndk-r29-linux.zip
unzip -x android-ndk-r29-linux.zip
rm android-ndk-r29-linux.zip
mv android-ndk-r29 ndk

git clone --recursive https://github.com/FWGS/hlsdk-portable

# for CMAKE_C_COMPILER_LAUNCHER, usually preinstalled on GitHub images
command -v ccache > /dev/null 2>&1 || sudo apt install -y ccache
