#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Download a file from a ModDB downloads/addons page.
#
# ModDB serves no direct links: the file page carries a /downloads/start/<id> (or /addons/start/<id>) link
# the start page carries a mirror link, and the mirror URL 302-redirects to a signed, expiring CDN URL on *.dl.dbolical.com.
#
# moddb.com replies 403 to anything without a browser User-Agent, but the CDN itself needs no UA and supports Range requests.
#
# Usage: moddb-download.sh <moddb-page-url> [output-path|-]
#   output-path may be a file, an existing directory (file is named after the CDN filename, default: current directory), or - for stdout.

set -e

UA='Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0'
MODDB='https://www.moddb.com'

die() { echo "${0##*/}: error: $*" >&2; exit 1; }

page=$1
out=${2:-.}

[ -n "$page" ] || die "usage: ${0##*/} <moddb-page-url> [output-path|-]"

start=$(curl -sf -A "$UA" "$page" | grep -oE '/(downloads|addons)/start/[0-9]+' | head -n 1)
[ -n "$start" ] || die "no start link found on $page (not a ModDB download page?)"

mirror=$(curl -sf -A "$UA" -e "$page" "$MODDB$start" | grep -oE '/(downloads|addons)/mirror/[^"]+' | head -n 1)
[ -n "$mirror" ] || die "no mirror link found on $MODDB$start"

# resolve the redirect ourselves to learn the real filename from the CDN URL
cdn=$(curl -sf -A "$UA" -o /dev/null -w '%{redirect_url}' "$MODDB$mirror")
[ -n "$cdn" ] || die "mirror $mirror did not redirect to a CDN URL"

if [ "$out" = "-" ]; then
	exec curl -sf "$cdn"
fi

if [ -d "$out" ]; then
	filename=${cdn##*/}
	filename=${filename%%\?*}
	# the CDN encodes spaces as '+'; decode those and percent-escapes
	filename=${filename//+/ }
	filename=$(printf '%b' "${filename//%/\\x}")
	[ -n "$filename" ] || die "cannot derive filename from CDN URL $cdn"
	out=$out/$filename
fi

echo "downloading $out from $cdn" >&2
curl -f -C - -o "$out" "$cdn"
