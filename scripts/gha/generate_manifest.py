#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# Walks out/ after artifacts have been collected and writes out/manifest.json
# describing every zip we shipped: which gamedir, which platform, which commit
# it was built from, and a sha256 so downloaders can verify it.
#
# Run from the repo root.

import hashlib
import json
import os
import sys
from pathlib import Path

OUT = Path('out')


def warn(msg):
    print(f'warning: {msg}', file=sys.stderr)


def sha256(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def split_stem(stem):
    parts = stem.rsplit('-', 2)
    if len(parts) < 3:
        return None, None
    gamedir, os_, arch = parts
    return gamedir, f'{os_}-{arch}'


# Load every gitinfo sidecar. Each one tells us which commit a given
# {gamedir, platform} pair was built from.
gitinfo = {}
for sidecar in sorted(OUT.glob('gitinfo-*.json')):
    gamedir, platform = split_stem(sidecar.stem[len('gitinfo-'):])
    if gamedir is None:
        warn(f'unrecognised sidecar name {sidecar.name}')
        continue
    if not gamedir:
        warn(f'empty gamedir in sidecar {sidecar.name}, skipping')
        continue
    gitinfo[gamedir, platform] = json.loads(sidecar.read_text())

gamedirs = {gd for gd, _ in gitinfo}
if not gamedirs:
    warn('no gitinfo-*.json sidecars found in out/')

def load_games(mod_keys, builds_source):
    # Attach the games[] content metadata from manifest.yml to each mod. The
    # manifest is keyed by gamedir (dl_name when set, GAMEDIR otherwise), while
    # manifest.yml is keyed by branch, so match on dl_name first and fall back
    # to the source branch recorded in the gitinfo sidecars.
    #
    import yaml
    entries = yaml.safe_load(Path('manifest.yml').read_text())

    by_dl_name = {}
    by_branch = {}
    for entry in entries:
        games = entry.get('games')
        if not games:
            continue
        if 'dl_name' in entry:
            by_dl_name[entry['dl_name']] = games
        else:
            by_branch.setdefault(entry['branch'], games)

    result = {}
    for key in mod_keys:
        if key in by_dl_name:
            result[key] = by_dl_name[key]
            continue
        # no dl_name: the key is the GAMEDIR; match by the build's source branch
        branches = {b for b in builds_source.get(key, ()) if b in by_branch}
        if len(branches) == 1:
            result[key] = by_branch[next(iter(branches))]
        elif not branches:
            warn(f'no games metadata matched mod {key!r}')
        else:
            warn(f'ambiguous games metadata for mod {key!r}: branches {branches}')
    return result

# Now walk the zips and bucket them under their gamedir. We use the same
# longest-prefix trick to recover the gamedir boundary from the filename.
mods = {gd: {'builds': {}} for gd in gamedirs}

for zip_path in sorted(OUT.glob('*.zip')):
    stem = zip_path.stem
    gamedir = max(
        (gd for gd in gamedirs if stem.startswith(gd + '-')),
        key=len,
        default=None,
    )
    if gamedir is None:
        warn(f'no gamedir matched for {zip_path.name}')
        continue

    platform = stem[len(gamedir) + 1:]
    source = gitinfo.get((gamedir, platform))
    if source is None:
        warn(f'no gitinfo sidecar for {gamedir} / {platform}')

    mods[gamedir]['builds'][platform] = {
        'filename': zip_path.name,
        'sha256': sha256(zip_path),
        'source': source,
    }

# gamedir -> set of source branches its builds were made from, for matching
# manifest.yml entries that have no dl_name
builds_source = {
    gd: {(b.get('source') or {}).get('branch')
         for b in mod['builds'].values()}
    for gd, mod in mods.items()
}
for gamedir, games in load_games(mods.keys(), builds_source).items():
    mods[gamedir]['games'] = games

server = os.environ.get('GITHUB_SERVER_URL', 'https://github.com')
repo = os.environ.get('GITHUB_REPOSITORY', '')

manifest = {
    'version': 1,
    'build': {
        'repo': f'{server}/{repo}',
        'commit': os.environ.get('GITHUB_SHA', ''),
        'run_id': os.environ.get('GITHUB_RUN_ID', ''),
    },
    'mods': mods,
}

out_path = OUT / 'manifest.json'
with out_path.open('w') as f:
    json.dump(manifest, f, indent=2, sort_keys=True)
    f.write('\n')

built = sum(1 for m in mods.values() if m['builds'])
print(f'wrote {out_path}: {len(mods)} mods, {built} with at least one build')
