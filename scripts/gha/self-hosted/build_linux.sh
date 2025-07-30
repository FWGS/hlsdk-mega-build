#!/bin/bash

# "booo, bash feature!"
declare -A TOOLCHAINS

TOOLCHAINS[i386]=/opt/x-tools/i686-unknown-linux-gnu/bin/i686-unknown-linux-gnu-
TOOLCHAINS[amd64]=/opt/x-tools/x86_64-unknown-linux-gnu/bin/x86_64-unknown-linux-gnu-
TOOLCHAINS[arm64]=/opt/x-tools/aarch64-unknown-linux-gnu/bin/aarch64-unknown-linux-gnu-
TOOLCHAINS[armhf]=/opt/x-tools/arm-unknown-linux-gnueabihf/bin/arm-unknown-linux-gnueabihf-

export CROSS_COMPILE=${TOOLCHAINS[$GH_CPU_ARCH]}

source scripts/gha/build_common.sh
