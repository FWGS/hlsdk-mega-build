#!/bin/bash

# "booo, bash feature!"
declare -A TOOLCHAINS

TOOLCHAINS[i386]=/home/runner/x-tools/i686-unknown-linux-gnu/bin/i686-unknown-linux-gnu-
TOOLCHAINS[amd64]=/home/runner/x-tools/x86_64-unknown-linux-gnu/bin/x86_64-unknown-linux-gnu-
TOOLCHAINS[arm64]=/home/runner/x-tools/arm64-unknown-linux-gnu/bin/arm64-unknown-linux-gnu-
TOOLCHAINS[armhf]=/home/runner/x-tools/armhf-unknown-linux-gnu/bin/armhf-unknown-linux-gnu-

export CROSS_COMPILE=${TOOLCHAINS[$GH_CPU_ARCH]}

source scripts/gha/build_common.sh
