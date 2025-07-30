#!/bin/bash

wineserver -k && wineserver -p

export MSVC_WINE_PATH=/opt/msvc

source scripts/gha/build_common.sh
