#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later

export VITASDK=/usr/local/vitasdk
export PATH="$VITASDK/bin:$PATH"

WAF_CONFIGURE_OPTS="--psvita"

source scripts/gha/build_common.sh
