#!/bin/bash

# TODO: remove this hack, put yq in PATH
if command -v yq > /dev/null 2>&1; then
	YQ=yq
else
	YQ=./yq
fi

MODS=$($YQ length manifest.yml)

build_with_waf()
{
	local WAF_ENABLE_VGUI_OPTION=''
	local WAF_ENABLE_AMD64_OPTION=''
	local WAF_ENABLE_MSVC_WINE=''

	if [ "$GH_CPU_ARCH" == "amd64" ]; then
		WAF_ENABLE_AMD64_OPTION="-8"
	elif [ "$GH_CPU_ARCH" == "i386" ]; then
		# not all waf-based hlsdk trees have vgui support
		python waf --help | grep 'enable-vgui' && WAF_ENABLE_VGUI_OPTION=--enable-vgui
	fi

	python waf \
		configure \
			--disable-werror \
			--enable-wafcache \
			$WAF_ENABLE_AMD64_OPTION \
			$WAF_ENABLE_VGUI_OPTION \
			$WAF_ENABLE_MSVC_WINE \
			$WAF_ENABLE_CROSS_COMPILE_ENV \
			$WAF_CONFIGURE_OPTS \
		install \
			--destdir=../stage || return 1

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
		7z a "../out/$1-$2.zip" "$1" || return 2
	popd || return 1

	return 0
}

for (( i = 0 ; i < MODS ; i++ )); do
	BRANCH=$($YQ -r ".[$i].branch" manifest.yml)

	GAMEDIR="" # expected to be set within build_hlsdk_portable_branch

	pushd hlsdk-portable || exit 1
	build_hlsdk_portable_branch "$BRANCH"
	SUCCESS=$?
	popd || exit 1

	if [ $SUCCESS -ne 0 ]; then
		continue
	fi

	pack_staged_gamedir "$GAMEDIR" "$GH_CPU_OS-$GH_CPU_ARCH"
done
