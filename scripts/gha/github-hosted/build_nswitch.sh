#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

cd "$GITHUB_WORKSPACE" || exit 1

# CCACHE_DIR points inside the workspace, so the cache is shared with the
# host and picked up by the actions/cache step
docker run --rm \
	-v "$GITHUB_WORKSPACE:$GITHUB_WORKSPACE" -w "$GITHUB_WORKSPACE" \
	-e GH_CPU_OS -e GH_CPU_ARCH \
	-e CCACHE_DIR -e CCACHE_MAXSIZE -e CCACHE_COMPILERCHECK -e CCACHE_SLOPPINESS \
	devkitpro/devkita64:latest \
	bash scripts/gha/github-hosted/build_nswitch_docker.sh
