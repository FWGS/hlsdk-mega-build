#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Extract a SFX-Factory! self-extracting installer without running it.
#
# Two variants exist (both used by the Poke646 series):
#  - "32-Bit ZIP Self Extractor": the exe carries two concatenated zip
#    archives, the first one is installer decor (background bitmap), the
#    second one is the payload.
#  - "32-Bit ACE Self Extractor": the exe carries an embedded ACE archive
#    at some offset (the **ACE** magic sits 7 bytes into the archive header).
#
# Usage: sfx-factory-extract.sh <installer.exe> [dest-dir]

set -e

die() { echo "${0##*/}: error: $*" >&2; exit 1; }

exe=$1
dest=${2:-.}

[ -n "$exe" ] || die "usage: ${0##*/} <installer.exe> [dest-dir]"
[ -f "$exe" ] || die "no such file: $exe"
mkdir -p "$dest"

# the stub identifies itself, e.g. "SFX-Factory! v2.0 32-Bit ZIP Self Extractor"
marker=$(LC_ALL=C grep -aom1 '32-Bit [A-Z]* Self Extractor' "$exe") || die "no SFX-Factory marker found in $exe"

payload=$(mktemp "${TMPDIR:-/tmp}/sfx-factory-XXXXXX")
trap 'rm -f "$payload"' EXIT

case "$marker" in
*ZIP*)
	# skip past the decor zip: find its end-of-central-directory record, the payload zip is the next local file header after it
	eocd=$(LC_ALL=C grep -abom1 $'PK\x05\x06' "$exe" | cut -d: -f1) || die "no end-of-central-directory record found in $exe"
	offset=$(LC_ALL=C grep -abo $'PK\x03\x04' "$exe" | awk -F: -v m="$eocd" '$1 > m { print $1; exit }')
	[ -n "$offset" ] || die "no payload zip found after offset $eocd in $exe"

	tail -c +$((offset + 1)) "$exe" > "$payload"
	# the payload's central directory carries mangled offsets (unzip/7z choke),
	# so extract sequentially from the local file headers instead
	bsdtar -C "$dest" -xf "$payload"
	;;
*ACE*)
	offset=$(LC_ALL=C grep -abom1 -- '\*\*ACE\*\*' "$exe" | cut -d: -f1) || die "no ACE signature found in $exe"
	[ "$offset" -ge 7 ] || die "ACE signature too close to file start in $exe"

	# the **ACE** magic sits 7 bytes into the archive header, carve from there so acefile doesn't have to scan the whole stub
	# (feeding it the exe as-is is pathologically slow)
	tail -c +$((offset - 6)) "$exe" > "$payload"

	# if you find better ace extractor, put it here. 7zip doesn't support it anymore and unace 2.5 produces corrupted TGA images
	# python-acefile thankfully doesn't bring extra dependencies
	python3 -c 'import acefile' 2> /dev/null || die "the python 'acefile' module is required to extract ACE archives (pip install acefile)"
	python3 -m acefile --extract -d "$dest" "$payload" > /dev/null
	;;
*)
	die "unknown SFX-Factory variant: $marker"
	;;
esac

echo "extracted $exe ($marker) to $dest" >&2
