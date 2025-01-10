#!/bin/bash

# FIXME: GH_CPU_ARCH is used for crosscompiling but on apple it's also host CPU arch, for now
if [ $GH_CPU_ARCH == "amd64" ]; then
	wget "https://github.com/mikefarah/yq/releases/download/v$YQ_VERSION/yq_darwin_amd64.tar.gz" -O- | tar -xzvf -
	mv yq_darwin_amd64 yq
	chmod +x yq
else
	wget "https://github.com/mikefarah/yq/releases/download/v$YQ_VERSION/yq_darwin_arm64.tar.gz" -O- | tar -xzvf -
	mv yq_darwin_arm64 yq
	chmod +x yq
fi

git clone --recursive https://github.com/FWGS/hlsdk-portable
