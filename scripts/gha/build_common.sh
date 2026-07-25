#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

# TODO: remove this hack, put yq in PATH
if command -v yq > /dev/null 2>&1; then
	YQ=yq
else
	YQ=./yq
fi

MODS=$($YQ length manifest.yml)

DEFAULT_REPO=https://github.com/FWGS/hlsdk-portable

build_with_waf()
{
	local WAF_ENABLE_VGUI_OPTION=''
	local WAF_ENABLE_AMD64_OPTION=''

	if [ "$GH_CPU_ARCH" == "amd64" ]; then
		WAF_ENABLE_AMD64_OPTION="-8"
	elif [ "$GH_CPU_ARCH" == "i386" ] && ( [ "$GH_CPU_OS" == "win32" ] || [ "$GH_CPU_OS" == "linux" ] || [ "$GH_CPU_OS" == "apple" ] ); then
		# not all waf-based hlsdk trees have vgui support
		python waf --help | grep 'enable-vgui' && WAF_ENABLE_VGUI_OPTION=--enable-vgui
	fi

	python waf --jobs=$(( $(nproc) + 1 )) \
		configure \
			--disable-werror \
			--enable-msvcdeps \
			-T release \
			$WAF_ENABLE_AMD64_OPTION \
			$WAF_ENABLE_VGUI_OPTION \
			$WAF_ENABLE_CROSS_COMPILE_ENV \
			$WAF_CONFIGURE_OPTS \
			$2 \
		install \
			--destdir="../stage/$1" || return 1

	return 0
}

build_with_cmake()
{
	local CMAKE_64BIT_OPTION=''
	local CMAKE_GENERATOR_OPTION='-GNinja'
	local CMAKE_BUILD_CONFIG_OPTION=''

	# equivalent of waf's -8 flag: hlsdk CMakeLists append -m32 on x86_64
	# hosts unless 64BIT is set. GoldSource only exists in 32-bit, so
	# don't build the compatible client library on 64-bit
	if [ "$GH_CPU_ARCH" == "amd64" ] || [ "$GH_CPU_ARCH" == "arm64" ]; then
		CMAKE_64BIT_OPTION='-D64BIT=ON -DGOLDSOURCE_SUPPORT=OFF'
	fi

	if [ "$GH_CPU_OS" == "win32" ]; then
		# cl.exe is not in PATH without vcvars, but the Visual Studio
		# generator can locate MSVC by itself, unlike Ninja
		CMAKE_GENERATOR_OPTION='-A x64'
		CMAKE_BUILD_CONFIG_OPTION='--config Release'
	fi

	# remove CMake cache to start configuration from zero
	rm -rf build/CMakeCache.txt

	cmake -B build $CMAKE_GENERATOR_OPTION \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX="../stage/$1" \
		$CMAKE_64BIT_OPTION \
		$CMAKE_CONFIGURE_OPTS \
		$2 \
		. || return 1

	cmake --build build $CMAKE_BUILD_CONFIG_OPTION --target install || return 1

	return 0
}

build_hlsdk_branch()
{
	# hlsdk source trees have mods in git branches
	git checkout "$1" || return 1

	# all hlsdk-portable derived trees have mod_options.txt file
	GAMEDIR=$(grep GAMEDIR mod_options.txt | tr '=' ' ' | cut -d' ' -f2 )

	if [ -z "$GAMEDIR" ]; then
		echo "error: could not parse GAMEDIR from mod_options.txt for branch $1" >&2
		return 1
	fi

	# several mods can genuinely share a game directory, so each mod is staged and published
	# under its own name to keep the archives from mixing up
	PACK_NAME=${3:-$GAMEDIR}

	# use cmake if requested by platform or by a mod tree
	if [ "${USE_CMAKE:-0}" -eq 1 ] || [ "$2" == "cmake" ]; then
		build_with_cmake "$PACK_NAME" "$4"
	elif [ "$2" == "waf" ]; then
		build_with_waf "$PACK_NAME" "$4"
	else
		echo "error: unknown build_system '$2' for branch $1" >&2
		return 1
	fi

	SUCCESS=$?

	if [ "$SUCCESS" -eq 2 ]; then # means something went wrong during install phase
		rm -rf "../stage/$PACK_NAME" # better cleanup
	fi

	if [ "$SUCCESS" -ne 0 ]; then
		return 2
	fi

	# write git metadata sidecar so the release job can build manifest.json.
	# only written on a successful build so the manifest never references
	# a (gamedir, platform) pair that has no corresponding zip.
	mkdir -p ../out
	printf '{"branch":"%s","commit":"%s","tree":"%s","url":"%s"}\n' \
		"$1" \
		"$(git rev-parse HEAD)" \
		"$(git rev-parse HEAD^{tree})" \
		"$(git remote get-url origin)" \
		> "../out/gitinfo-${PACK_NAME}-${GH_CPU_OS}-${GH_CPU_ARCH}.json"

	return 0
}

# $1 - mod (pack) name, $2 - game directory inside the archive, $3 - platform
pack_staged_gamedir()
{
	mkdir -p out || return 1

	pushd "stage/$1" || return 1
		7z a "../../out/$1-$3.zip" "$2" || return 2
	popd || return 1

	return 0
}

for (( i = 0 ; i < MODS ; i++ )); do
	BRANCH=$($YQ -r ".[$i].branch" manifest.yml)
	REPO=$($YQ -r ".[$i].repo // \"$DEFAULT_REPO\"" manifest.yml)
	MOD_BUILD_SYSTEM=$($YQ -r ".[$i].build_system // \"waf\"" manifest.yml)
	DL_NAME=$($YQ -r ".[$i].dl_name // \"\"" manifest.yml)
	MOD_CONFIGURE_OPTS=$($YQ -r ".[$i].configure_opts // \"\"" manifest.yml)
	REPO_DIR=$(basename "$REPO" .git)

	GAMEDIR=""  # expected to be set within build_hlsdk_branch
	PACK_NAME="" # ditto, dl_name if set, GAMEDIR otherwise

	# deps scripts only pre-clone hlsdk-portable, fetch other source trees
	# on demand
	if [ ! -d "$REPO_DIR" ]; then
		git clone --recursive "$REPO" "$REPO_DIR" || continue
	fi

	pushd "$REPO_DIR" || exit 1
	build_hlsdk_branch "$BRANCH" "$MOD_BUILD_SYSTEM" "$DL_NAME" "$MOD_CONFIGURE_OPTS"
	SUCCESS=$?
	popd || exit 1

	if [ $SUCCESS -ne 0 ]; then
		continue
	fi

	pack_staged_gamedir "$PACK_NAME" "$GAMEDIR" "$GH_CPU_OS-$GH_CPU_ARCH"
done
