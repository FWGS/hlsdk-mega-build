# `manifest.json` schema

Each release on this repository ships a `manifest.json` asset alongside the per-mod
ZIP archives. The manifest describes every binary in the release: which gamedir it
is for, which platform it targets, which upstream commit it was built from, and a
sha256 checksum for verification.

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
