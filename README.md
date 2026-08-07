# hlsdk-mega-build

This repository uses cron job to rebuild all known HLSDK branches and puts prebuilt binaries on GitHub releases where they could be accessed by anyone.

## Manifest

The definition of mods is kept within `manifest.yml` file which is a YAML file consisting of array of structured data:

| Key     | Value |
|---------|-------|
|`branch` |Branch name used for in the repository.|
|`repo`   |URL of Git repository. If not set, defaults to hlsdk-portable.|
|`dl_name`|Name of the published archive and manifest.json key. If not set, defaults to the game directory from mod_options.txt. Must be set when several branches share a game directory (e.g. bot10 and bubblemod both install into valve).|
|`games`  |An array of game objects, see below. Used to automatically fetching game libraries.|
|`build_system`|A string that contains preferred build system, can be either `"cmake"` or `"waf"`. If not set, `waf` is the default|
|`configure_opts`|Passed verbatim into build systen's configure stage, if such exists|
|`commit` |If set, this exact revision is checked out instead of the branch tip.|

### Game object

| Key             | Value |
|-----------------|-------|
|`title`          |Human readable title of the game.|
|`dir`            |Array of directories to install from the unpacked content archive, the first one being the gamedir. Anything else in the archive is ignored. Spelled exactly as in the archive.|
|`url`            |Canonical home page of the game.|
|`dl_url`         |Download page or direct file link, depending on `dl_method`, of the latest version of the game.|
|`dl_method`      |How to download `dl_url`: `moddb` (resolve with `scripts/moddb-download.sh`), `get` (plain HTTP GET), `get_with_redirect` (HTTP GET following redirects), `steam` (fetch from Steam, see the `steam` object), `none` (nothing to download).|
|`need_browser_ua`|Boolean, enable if server returns 403 unless a browser User-Agent is sent. Only meaningful for `get`/`get_with_redirect`, as `moddb` always implies it. Defaults to `false`.|
|`dl_sha256sum`   |sha256 checksum of the downloaded file, verify the checksum of the file before passing it to an unpacker.|
|`unpack_method`  |Tool that unpacks the download: `unzip`, `unrar`, `7z`, `innoextract`, `unshield`, `cicdec`, `sfx_factory`.|
|`unpack_root`    |Path inside the archive the game content is taken from. Unset means the archive root.|
|`unpack_to`      |If set, the content at `unpack_root` is the gamedir content itself (if the archive carries no gamedir folder) and is installed into a directory with this name. If unset, `unpack_root` contains the gamedir folder(s) listed in `dir`.|
|`steam`          |If set, the game is available from Steam. The object must have `app_id` with Steam AppID and `depot_ids` with array of **content** depot IDs.|

## Client scripts

- `scripts/moddb-download.sh <page-url> [output]` — resolves ModDB's start/mirror indirection and downloads a file from a ModDB downloads/addons page.
- `scripts/sfx-factory-extract.sh <installer.exe> [dest]` — extracts a SFX-Factory! self-extracting installer (both the ZIP and ACE variants) without running it.
- `scripts/download_mod.py <gamedir>` — downloads and installs the prebuilt game libraries for the current platform from the `continuous` release, driven by the published `manifest.json`.
- `scripts/sample_mod_install.py <mod>` — sample end-to-end installer: fetches the game content per the `games` metadata above, verifies and unpacks it, then installs the game libraries via `download_mod.py`. Reads `manifest.yml` for now; will switch to the published `manifest.json` once the `games` metadata is embedded there.

### Required tools

The client scripts shell out to external tools depending on the `dl_method`/`unpack_method` of the game being installed. Only the ones a given mod actually uses are needed.

| Tool                    | Needed for |
|-----------------------=-|-----------|
|`python3` (3.6+)         |All scripts.|
|`PyYAML` (python module) |`sample_mod_install.py`, until it reads the generated `manifest.json` instead of `manifest.yml`.|
|`curl`                   |`moddb-download.sh` (i.e. every `moddb` download).|
|`unzip`                  |`unpack_method: unzip`.|
|`unrar`                  |`unpack_method: unrar`.|
|`7z`                     |`unpack_method: 7z`.|
|`innoextract`            |`unpack_method: innoextract`.|
|`unshield`               |`unpack_method: unshield`.|
|`bsdtar` (libarchive)    |`unpack_method: sfx_factory`.|
|`acefile` (python module)|`unpack_method: sfx_factory`.|

## Build scripts

The `deps` scripts prepare to build environment for a specified target. The `build` scripts parse manifest, run build for all branches and create archives for all games in `out` directory. After that it's collected and published on GitHub releases page.

If a `patches/<branch>` directory exists, the `*.patch` files in it are applied with `git apply` after checkout, before the build. See `patches/README.md`.

## TODO

- [x] Support other build systems than Waf
- [x] Support other repos than `hlsdk-portable`.
- [ ] Add more build targets, ideally all supported by Xash3D FWGS.
- [ ] Implement a client which will look up which game libraries are missing for selected gamedir and download them from this repository, optionally download the game files from ModDB and Steam, apply patches, have a beautiful GUI......
- [x] Cache object files for faster rebuilds (ccache, everywhere except MSVC).
- [x] Make this run daily? Bi-weekly?
- [x] Machine-readable info on mod downloading and unpacking
