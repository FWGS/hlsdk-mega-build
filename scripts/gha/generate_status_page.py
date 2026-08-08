#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# Reads out/manifest.json produced by generate_manifest.py and writes
# page/index.html: a build status table with mods as rows and platforms as
# columns. Successful builds link to the released ZIP, failures show a cross.
#
# Run from the repo root after generate_manifest.py.

import html
import json
import os
import time
from pathlib import Path

OUT = Path('out')
PAGE = Path('page')

# canonical column order, platforms not listed here are appended at the end
PLATFORM_ORDER = [
	'linux-amd64', 'linux-i386', 'linux-arm64', 'linux-armhf', 'linux-riscv64',
	'android-amd64', 'android-i386', 'android-arm64', 'android-armv7l',
	'nswitch-arm64', 'psvita-armv7hf',
	'win32-amd64', 'apple-arm64',
]

server = os.environ.get('GITHUB_SERVER_URL', 'https://github.com')
repo = os.environ.get('GITHUB_REPOSITORY', 'FWGS/hlsdk-mega-build')
tag = os.environ.get('RELEASE_TAG', 'continuous')
run_id = os.environ.get('GITHUB_RUN_ID', '')
sha = os.environ.get('GITHUB_SHA', '')

manifest = json.loads((OUT / 'manifest.json').read_text())
mods = manifest.get('mods', {})

platforms = [p for p in PLATFORM_ORDER
			 if any(p in m.get('builds', {}) for m in mods.values())]
platforms += sorted({p for m in mods.values() for p in m.get('builds', {})}
					- set(platforms))

download_base = f'{server}/{repo}/releases/download/{tag}'


def cell(mod, plat):
	build = mods[mod].get('builds', {}).get(plat)
	if build is None:
		return '<td class="fail" title="build failed">✕</td>'

	source = build.get('source') or {}
	tooltip = 'download %s' % build['filename']
	if source:
		tooltip += ' (%s @ %s%s)' % (
			source.get('branch', '?'),
			source.get('commit', '?')[:12],
			', patched' if source.get('patched') else '')

	return '<td class="ok"><a href="%s/%s" title="%s">✓</a></td>' % (
		download_base, html.escape(build['filename']), html.escape(tooltip))

def chip(mod, plat):
	label = html.escape(plat.replace('-', ' ', 1))
	build = mods[mod].get('builds', {}).get(plat)
	if build is None:
		return '<span class="chip fail" title="build failed">%s</span>' % label

	return '<a class="chip ok" href="%s/%s" title="download %s">%s</a>' % (
		download_base, html.escape(build['filename']),
		html.escape(build['filename']), label)

def source_links(mod):
	pairs = {(s.get('url'), s.get('branch'))
			 for b in mods[mod].get('builds', {}).values()
			 for s in [b.get('source') or {}] if s.get('url') and s.get('branch')}
	links = []
	for url, branch in sorted(pairs):
		if url.endswith('.git'):
			url = url[:-len('.git')]
		label = 'source' if len(pairs) == 1 else 'source (%s)' % html.escape(branch)
		links.append('<a href="%s/tree/%s" title="%s">%s</a>' % (
			html.escape(url), html.escape(branch),
			html.escape('%s @ %s' % (url, branch)), label))
	return links

def mod_meta(mod):
	# canonical title linking to the game's home page, the content download
	# link where the manifest carries one, and the mod source code
	lines = []
	for game in mods[mod].get('games') or []:
		title = html.escape(game.get('title', mod))
		url = game.get('url')
		dl_url = game.get('dl_url')
		line = '<a href="%s">%s</a>' % (html.escape(url), title) if url else title
		if dl_url:
			line += ' · <a href="%s">download</a>' % html.escape(dl_url)
		lines.append(line)
	srcs = source_links(mod)
	if srcs:
		if lines:
			lines[0] += ' · ' + ' · '.join(srcs)
		else:
			lines.append(' · '.join(srcs))
	if not lines:
		return ''
	return '<div class="modmeta">%s</div>' % '<br>'.join(lines)

rows = []
cards = []
for mod in sorted(mods, key=str.lower):
	meta = mod_meta(mod)
	cells = ''.join(cell(mod, p) for p in platforms)
	rows.append('<tr><th>%s%s</th>%s</tr>' % (html.escape(mod), meta, cells))
	chips = ''.join(chip(mod, p) for p in platforms)
	cards.append('<li><h2>%s</h2>%s<div class="chips">%s</div></li>'
				 % (html.escape(mod), meta, chips))

# group platform columns by OS for a two-level header
os_groups = []
for p in platforms:
	os_, _, arch = p.partition('-')
	if os_groups and os_groups[-1][0] == os_:
		os_groups[-1][1].append(arch)
	else:
		os_groups.append((os_, [arch]))

head_os = ''.join('<th colspan="%d" class="os">%s</th>' % (len(a), html.escape(o))
				  for o, a in os_groups)
head_arch = ''.join('<th class="arch">%s</th>' % html.escape(a)
					for _, archs in os_groups for a in archs)

built = sum(1 for m in mods.values() if m.get('builds'))
total_cells = len(mods) * len(platforms)
ok_cells = sum(len(m.get('builds', {})) for m in mods.values())
timestamp = time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime())

run_link = f'{server}/{repo}/actions/runs/{run_id}' if run_id else f'{server}/{repo}/actions'

page = f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HLSDK Mega Build status</title>
<style>
:root {{
	--bg: #fbfaf8; --fg: #24292e; --muted: #6a737d; --line: #e4e1db;
	--head-bg: #f2f0ec; --row-hover: #f4f2ee;
	--ok: #2f7d43; --ok-hover-bg: #e2efe5;
	--fail: #b0453c; --fail-bg: #f7eceb;
}}
@media (prefers-color-scheme: dark) {{
	:root {{
		--bg: #1b1d1e; --fg: #d6d3cd; --muted: #8b8f94; --line: #3a3d3f;
		--head-bg: #232628; --row-hover: #26292b;
		--ok: #6fbf82; --ok-hover-bg: #24382a;
		--fail: #d3796f; --fail-bg: #362725;
	}}
}}
* {{ box-sizing: border-box; }}
body {{ font-family: system-ui, sans-serif; margin: 1.5rem auto; max-width: 72rem;
	   padding: 0 1rem; background: var(--bg); color: var(--fg); }}
h1 {{ font-size: 1.35rem; }}
p {{ color: var(--muted); max-width: 60ch; }}
p a {{ color: inherit; }}
.tablewrap {{ overflow-x: auto; border: 1px solid var(--line); border-radius: 4px; }}
table {{ border-collapse: collapse; width: 100%; font-variant-numeric: tabular-nums; }}
th, td {{ border: 1px solid var(--line); padding: 0; text-align: center; }}
thead th {{ background: var(--head-bg); padding: .3rem .55rem; font-weight: 600; }}
thead .arch {{ font-weight: 400; font-size: .8rem; color: var(--muted); }}
tbody th {{ text-align: left; font-weight: 500; padding: .3rem .6rem; white-space: nowrap;
		   position: sticky; left: 0; background: var(--bg); }}
tbody tr:hover th {{ background: var(--row-hover); }}
tbody tr:hover td {{ background: var(--row-hover); }}
.modmeta {{ font-weight: 400; font-size: .78rem; color: var(--muted); margin-top: .1rem; }}
.modmeta a {{ color: inherit; text-decoration: underline; text-underline-offset: 2px; }}
.cards .modmeta {{ margin: -.25rem 0 .4rem; }}
td.ok a {{ display: block; padding: .3rem .55rem; color: var(--ok); font-weight: 700;
		  text-decoration: none; }}
td.ok a:hover, td.ok a:focus-visible {{ background: var(--ok-hover-bg); text-decoration: underline;
		  text-underline-offset: 3px; outline: none; }}
td.fail {{ color: var(--fail); background: var(--fail-bg); padding: .3rem .55rem; }}
footer {{ margin-top: 1rem; font-size: .85rem; color: var(--muted); }}
footer a {{ color: inherit; }}
/* narrow screens get a card list instead of an 11-column table */
.cards {{ display: none; list-style: none; margin: 0; padding: 0; }}
.cards li {{ border: 1px solid var(--line); border-radius: 4px; padding: .5rem .65rem;
			margin-bottom: .5rem; background: var(--head-bg); }}
.cards h2 {{ font-size: .95rem; margin: 0 0 .4rem; }}
.chips {{ display: flex; flex-wrap: wrap; gap: .3rem; }}
.chip {{ font-size: .78rem; padding: .15rem .5rem; border-radius: 999px;
		border: 1px solid var(--line); white-space: nowrap; }}
.chip.ok {{ color: var(--ok); border-color: var(--ok); text-decoration: none; }}
.chip.ok::before {{ content: "✓ "; font-weight: 700; }}
.chip.ok:active, .chip.ok:hover {{ background: var(--ok-hover-bg); }}
.chip.fail {{ color: var(--fail); background: var(--fail-bg); opacity: .8; }}
.chip.fail::before {{ content: "✕ "; }}
@media (max-width: 640px) {{
	.tablewrap {{ display: none; }}
	.cards {{ display: block; }}
}}
</style>
</head>
<body>
<h1>HLSDK Mega Build status</h1>
<p>{ok_cells}/{total_cells} builds succeeded across {len(mods)} mods and {len(platforms)} platforms.
Every <span style="color: var(--ok); font-weight: 700">✓</span> is a download link to the ZIP
from the <a href="{server}/{repo}/releases/tag/{tag}">{html.escape(tag)}</a> release.</p>
<div class="tablewrap">
<table>
<thead>
<tr><th rowspan="2">mod</th>{head_os}</tr>
<tr>{head_arch}</tr>
</thead>
<tbody>
{chr(10).join(rows)}
</tbody>
</table>
</div>
<ul class="cards">
{chr(10).join(cards)}
</ul>
<footer>
Generated {timestamp} by <a href="{run_link}">run {html.escape(run_id) or '?'}</a>
from <a href="{server}/{repo}/commit/{sha}">{html.escape(sha[:7]) or '?'}</a>.
Machine-readable: <a href="{download_base}/manifest.json">manifest.json</a>.
</footer>
</body>
</html>
'''

PAGE.mkdir(parents=True, exist_ok=True)
(PAGE / 'index.html').write_text(page)
print(f'wrote page/index.html: {len(mods)} mods x {len(platforms)} platforms, {ok_cells}/{total_cells} ok')
