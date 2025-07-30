#!/bin/bash

cd "$GITHUB_WORKSPACE" || exit 1

git clone --recursive https://github.com/FWGS/hlsdk-portable
