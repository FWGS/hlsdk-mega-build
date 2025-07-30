#!/bin/bash

cd "$GITHUB_WORKSPACE" || exit 1

# "booo, bash feature!", -- posix sh users, probably
declare -A BASE_BUILD_PACKAGES

BASE_BUILD_PACKAGES[common]=""
BASE_BUILD_PACKAGES[amd64]="build-essential"
BASE_BUILD_PACKAGES[i386]="gcc-multilib g++-multilib"
BASE_BUILD_PACKAGES[arm64]="crossbuild-essential-arm64"
BASE_BUILD_PACKAGES[armhf]="crossbuild-essential-armhf"
BASE_BUILD_PACKAGES[riscv64]="crossbuild-essential-riscv64"
BASE_BUILD_PACKAGES[ppc64el]="crossbuild-essential-ppc64el"

regenerate_sources_list()
{
	# this is evil but to speed up update, specify all repositories manually
	sudo rm /etc/apt/sources.list
	sudo rm -rf /etc/apt/sources.list.d

	for i in focal focal-updates focal-backports focal-security; do
		echo "deb [arch=$GH_CPU_ARCH] http://azure.ports.ubuntu.com/ubuntu-ports $i main universe" | sudo tee -a /etc/apt/sources.list
		echo "deb [arch=amd64] http://azure.archive.ubuntu.com/ubuntu $i main universe" | sudo tee -a /etc/apt/sources.list
	done
}

if [ "$GH_CPU_ARCH" != "amd64" ] && [ -n "$GH_CPU_ARCH" ]; then
	if [ "$GH_CPU_ARCH" != "i386" ]; then
		regenerate_sources_list
	fi
	sudo dpkg --add-architecture "$GH_CPU_ARCH"
fi

sudo apt update || exit 2
sudo apt install aptitude || exit 2 # aptitude is just more reliable at resolving dependencies

# shellcheck disable=SC2086 # splitting is intended here
sudo aptitude install -y ${BASE_BUILD_PACKAGES[common]} ${BASE_BUILD_PACKAGES[$GH_CPU_ARCH]} || exit 2

####################
git clone --recursive https://github.com/FWGS/hlsdk-portable

wget "https://github.com/mikefarah/yq/releases/download/v$YQ_VERSION/yq_linux_amd64.tar.gz" -O- | tar -xzvf -
mv yq_linux_amd64 yq
