#!/bin/bash

# "booo, bash feature!"
declare -A WAF_CONFIGURE_PLATFORM_OPTS

WAF_CONFIGURE_PLATFORM_OPTS[i386]=--android=x86,clang,21
WAF_CONFIGURE_PLATFORM_OPTS[amd64]=--android=x86_64,clang,21
WAF_CONFIGURE_PLATFORM_OPTS[arm64]=--android=arm64-v8a,clang,21
WAF_CONFIGURE_PLATFORM_OPTS[armel]=--android=armeabi-v7a,clang,21

export ANDROID_NDK_HOME=/opt/android/ndk/28.2.13676358/

WAF_CONFIGURE_OPTS=${WAF_CONFIGURE_PLATFORM_OPTS[$GH_CPU_ARCH]}

source scripts/gha/build_common.sh
