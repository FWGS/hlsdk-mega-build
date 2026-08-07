# `manifest.json` schema

Each release on this repository ships a `manifest.json` asset alongside the per-mod
ZIP archives. It is produced by `scripts/gha/generate_manifest.py`, which walks the
built ZIPs in `out/` and merges in the `games` content metadata from `manifest.yml`.
The manifest describes every binary in the release: which gamedir it is for, which
platform it targets, which upstream commit it was built from, and a sha256 checksum
for verification; and, per mod, where to download the game content itself and how to
unpack it (the `games` array).

This document is the contract for downstream consumers (launchers, installers,
update tools). The format is versioned: only **incompatible** changes bump
`version`. New optional fields can appear without a version bump and will be
documented separately — consumers must ignore unknown fields, not reject them.

## Minimal example

```json
{
	"version": 1,
	"build": {
		"repo": "https://github.com/FWGS/hlsdk-mega-build",
		"commit": "e0f9957cea4f3724c2a07960adddee308624f8fa",
		"run_id": "25482546760"
	},
	"mods": {
		"valve": {
			"builds": {
				"linux-amd64": {
					"filename": "valve-linux-amd64.zip",
					"sha256": "6e96e45029870a9b08cff2ed6ac840ccde3edce244327cc1bddefa1e555bc81f",
					"source": {
						"branch": "master",
						"commit": "211fd687a124df38e6b5b7e4f93861db84b7b09b",
						"tree": "6501b406442a380a7362460a9cd6f8417769708a",
						"url": "https://github.com/FWGS/hlsdk-portable"
					}
				}
			}
		}
	}
}
```

## Field reference

| Path                               | Type    | Presence | Nullability | Description |
|------------------------------------|---------|----------|-------------|-------------|
| `version`                          | integer | required | never       | Schema version. Currently `1`. Bumped on breaking changes. |
| `build`                            | object  | required | never       | Metadata about the CI run that produced this manifest. |
| `build.repo`                       | string  | required | emptyable   | URL of the repository that produced this build. |
| `build.commit`                     | string  | required | emptyable   | Commit of `hlsdk-mega-build` that drove the build. |
| `build.run_id`                     | string  | required | emptyable   | GitHub Actions run ID. Useful for tracing back to logs. |
| `mods`                             | object  | required | never       | Map of `gamedir` -> mod entry. Keys are the gamedir names (e.g. `valve`, `gearbox`, `bshift`). Keys are never empty. |
| `mods.<gamedir>`                   | object  | optional | never       | Per-mod entry. |
| `mods.<gamedir>.builds`            | object  | required | emptyable   | Map of `<os>-<arch>` -> build entry. An empty object means no platform built successfully for this mod in this run. |
| `mods.<gamedir>.builds.<platform>` | object  | optional | never       | One platform's binary. |
| `...builds.<platform>.filename`    | string  | required | never       | Name of the ZIP asset attached to the same release. |
| `...builds.<platform>.sha256`      | string  | required | never       | Lowercase hex sha256 of the ZIP. |
| `...builds.<platform>.source`      | object  | required | nullable    | Upstream source info. `null` if the gitinfo sidecar was missing for this build (should not happen in normal CI runs; treat as "unknown source"). |
| `...source.branch`                 | string  | required | never       | The hlsdk-portable branch that was checked out. |
| `...source.commit`                 | string  | required | never       | Upstream commit hash. |
| `...source.tree`                   | string  | required | never       | Upstream tree hash (`HEAD^{tree}`). Useful for content-addressed comparison across branches. |
| `...source.url`                    | string  | required | never       | Upstream remote URL (typically `https://github.com/FWGS/hlsdk-portable`). |
| `...source.patched`                | boolean | optional | never       | `true` if `hlsdk-mega-build` patches were applied on top of the upstream commit — `tree` then refers to the unpatched upstream tree. Absent or `false` means a pristine upstream build. |
| `mods.<gamedir>.games`             | array   | optional | never       | Game **content** metadata carried over from `manifest.yml`, one object per game. Absent when the mod's `manifest.yml` entry carries no game metadata; the binaries in `builds` are then useless without content obtained by other means. |
| `...games[].title`                 | string  | required | never       | Human readable title of the game. |
| `...games[].dir`                   | array of strings | optional | never | Directories to install from the unpacked content archive, the first one being the gamedir. Anything else in the archive is ignored. Spelled exactly as in the archive. Absent when the content layout is unknown (e.g. installers no tool can unpack yet). |
| `...games[].url`                   | string  | required | never       | Canonical home page of the game. |
| `...games[].dl_url`                | string  | optional | never       | Download page or direct file link, depending on `dl_method`, of the latest version of the game. Absent when `dl_method` is `steam` or `none`. |
| `...games[].dl_method`             | string  | required | never       | How to download `dl_url`: `moddb` (resolve the start/mirror indirection like `scripts/moddb-download.sh` does), `get` (plain HTTP GET), `get_with_redirect` (HTTP GET following redirects), `steam` (fetch via the `steam` object), `none` (nothing to download). Unknown values must be treated as "cannot download". |
| `...games[].need_browser_ua`       | boolean | optional | never       | Enable if the server returns 403 unless a browser User-Agent is sent. Only meaningful for `get`/`get_with_redirect`, as `moddb` always implies it. Absent means `false`. |
| `...games[].dl_sha256sum`          | string  | optional | never       | sha256 checksum of the downloaded file. Verify it before passing the file to an unpacker, and treat a mismatch as "upstream changed the release", not as a transfer error. |
| `...games[].unpack_method`         | string  | optional | never       | Tool that unpacks the download: `unzip`, `unrar`, `7z`, `innoextract`, `unshield`, `cicdec` (Clickteam installer), `sfx_factory` (SFX-Factory installer, handled by `scripts/sfx-factory-extract.sh`). Unknown values must be treated as "cannot unpack". |
| `...games[].unpack_root`           | string  | optional | never       | Path inside the archive the game content is taken from. Absent means the archive root. |
| `...games[].unpack_to`             | string  | optional | never       | If present, the content at `unpack_root` is the gamedir content itself (the archive carries no gamedir folder) and must be installed into a directory with this name. If absent, `unpack_root` contains the gamedir folder(s) listed in `dir`. |
| `...games[].steam`                 | object  | optional | never       | Present when the game is available from Steam. |
| `...steam.app_id`                  | integer | required | never       | Steam AppID. |
| `...steam.depot_ids`               | array of integers | required | never | **Content** depot IDs (binaries depots are excluded — the `builds` of this manifest replace them). |

### Platform key format

`<os>-<arch>`

Not every combination is built, as some might fail, timeout or simply don't exist. The possible platform combinations always follow definitions in https://github.com/FWGS/library-suffix/.

## Consumer guidance

- **Check `version`.** If you read `manifest.json`, verify the `version` is one
  you understand. A consumer that does not recognise the version must refuse to
  proceed rather than guess. New optional fields are added without bumping
  `version` — ignore unknown fields, do not reject them.
- **Iterate `mods` by key.** The gamedir is the canonical identifier. Do not
  derive it from `filename`, treat `filename` as opaque.
- **Verify with `sha256`.** The hash covers the ZIP file as published; recompute
  after download.
- **Tolerate missing platforms.** A mod may have an empty `builds: {}` if every
  platform failed in a given run. This is not a manifest error.
- **Tolerate `source: null`.** Display "unknown source".

## Versioning policy

`version` is bumped only on **incompatible** changes — i.e. changes that would
break a consumer that was correctly written against the previous version.

Bumps `version`:
- Renaming or removing a field.
- Changing a field's type.
- Changing nullability from "never null" to "nullable".
- Changing the meaning of an existing field.

Does **not** bump `version` (documented separately):
- Adding a new optional field anywhere in the tree.
- Adding a new platform key under `builds`.
- Adding a new entry under `mods`.

Consumers must ignore unknown fields. They must not treat the appearance of a
new field as an error.

## Changelog

1. Initial version intended for public use.

Unversioned additions (optional fields, no `version` bump):

- `mods.<gamedir>.games` — game content download/unpack metadata carried over
  from `manifest.yml` (see the field reference above), emitted by
  `generate_manifest.py` for every mod whose `manifest.yml` entry has a `games`
  block. Consumers must tolerate its absence, since a source entry need not
  carry game metadata.
