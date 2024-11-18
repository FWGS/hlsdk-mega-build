#!/bin/bash

# "booo, bash feature!"
declare -A ARCH_TRIPLET CROSS_COMPILE_CC CROSS_COMPILE_CXX
ARCH_TRIPLET[amd64]=x86_64-linux-gnu
ARCH_TRIPLET[i386]=i386-linux-gnu
ARCH_TRIPLET[arm64]=aarch64-linux-gnu
ARCH_TRIPLET[armhf]=arm-linux-gnueabihf
ARCH_TRIPLET[riscv64]=riscv64-linux-gnu
ARCH_TRIPLET[ppc64el]=powerpc64le-linux-gnu
CROSS_COMPILE_CC[amd64]=cc
CROSS_COMPILE_CC[i386]="cc -m32"
CROSS_COMPILE_CXX[amd64]=c++
CROSS_COMPILE_CXX[i386]="c++ -m32"
for i in arm64 armhf riscv64 ppc64el; do
	CROSS_COMPILE_CC[$i]=${ARCH_TRIPLET[$i]}-gcc
	CROSS_COMPILE_CXX[$i]=${ARCH_TRIPLET[$i]}-g++
done
export PKG_CONFIG_PATH=${ARCH_TRIPLET[$GH_CPU_ARCH]}
export CC=${CROSS_COMPILE_CC[$GH_CPU_ARCH]}
export CXX=${CROSS_COMPILE_CXX[$GH_CPU_ARCH]}

MODS=$(./yq length manifest.yml)

build_with_waf()
{
	local WAF_ENABLE_VGUI_OPTION=''
	local WAF_ENABLE_AMD64_OPTION=''

	# run build in it's out build folder
	export WAFLOCK=".lock-waf_$1"

	if [ "$GH_CPU_ARCH" == "amd64" ]; then
		WAF_ENABLE_AMD64_OPTION="-8"
	elif [ "$GH_CPU_ARCH" == "i386" ]; then
		# not all waf-based hlsdk trees have vgui support
		python waf --help | grep 'enable-vgui' && WAF_ENABLE_VGUI_OPTION=--enable-vgui

		export CXXFLAGS="-I../../external"
	fi

	python waf -o "build/$1" \
		configure \
			--disable-werror \
			$WAF_ENABLE_AMD64_OPTION \
			$WAF_ENABLE_VGUI_OPTION \
		install \
			--destdir=../stage || return 1

	unset WAFLOCK
	unset CXXFLAGS

	return 0
}

build_hlsdk_portable_branch()
{
	# hlsdk-portable has mods in git branches
	git checkout "$1" || return 1

	# all hlsdk-portable branches have mod_options.txt file
	GAMEDIR=$(grep GAMEDIR mod_options.txt | tr '=' ' ' | cut -d' ' -f2 )

	build_with_waf "$GAMEDIR"
	SUCCESS=$?

	if [ $SUCCESS -eq 2 ]; then # means something went wrong during install phase
		rm -rf "../stage/$GAMEDIR" # better cleanup
	fi

	if [ $SUCCESS -ne 0 ]; then
		return 2
	fi

	return 0
}

pack_staged_gamedir()
{
	mkdir -p out || return 1

	pushd stage/ || return 1
		zip -r "../out/$1-$2.zip" "$1" || return 2
	popd || return 1

	return 0
}

for (( i = 0 ; i < MODS ; i++ )); do
	BRANCH=$(./yq -r ".[$i].branch" manifest.yml)

	GAMEDIR="" # expected to be set within build_hlsdk_portable_branch

	pushd hlsdk-portable || exit 1
		build_hlsdk_portable_branch "$BRANCH"
		SUCCESS=$?

		if [ $SUCCESS -ne 0 ]; then
			continue
		fi
	popd || exit 1

	pack_staged_gamedir "$GAMEDIR" "$GH_CPU_OS-$GH_CPU_ARCH"
done
