#!/bin/bash

wineserver -k && wineserver -p

export MSVC_WINE_PATH=/opt/msvc

WAF_CONFIGURE_OPTS="--enable-msvc-wine"

source scripts/gha/build_common.sh
