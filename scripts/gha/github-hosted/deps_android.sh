#!/bin/bash

cd "$GITHUB_WORKSPACE" || exit 1

wget https://dl.google.com/android/repository/android-ndk-r29-linux.zip
unzip -x android-ndk-r29-linux.zip
rm android-ndk-r29-linux.zip
mv android-ndk-r29 ndk

git clone --recursive https://github.com/FWGS/hlsdk-portable
