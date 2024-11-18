# hlsdk-mega-build

This repository uses cron job to rebuild all known HLSDK branches and puts prebuilt binaries on GitHub releases where they could be accessed by anyone.

## Manifest

The definition of mods is kept within `manifest.yml` file which is a YAML file consisting of array of structured data:

| Key     | Value |
|---------|-------|
|`branch` |Branch name used for in the repository.|
|`repo`   |URL of Git repository. If not set, defaults to hlsdk-portable.|
|`dl_name`|If set, it means that game directory specified in mod_options.txt differs from branch name.|
|`games`  |An array of game objects, see below. Used to automatically fetching game libraries.|

### Game object

| Key   | Value |
|-------|-------|
|`title`|Human readable title of the game.|
|`dir`  |Game directory name of the game.|
|`steam`|If set, the game is available from Steam. The object must have `app_id` with Steam AppID and `depot_id` with array of **content** depot IDs.|
|`moddb`|If set, the game is available from ModDB. The object must have `url` with ModDB page, `dl` with main ModDBs download link and array of `patches` links, if they are any|

## Build scripts

The `deps` scripts prepare to build environment for a specified target. The `build` scripts parse manifest, run build for all branches and create archives for all games in `out` directory. After that it's collected and published on GitHub releases page.

## TODO

- [ ] Support other build systems than Waf and other repos than `hlsdk-portable`.
- [ ] Add more build targets, ideally all supported by Xash3D FWGS.
- [ ] Implement a client which will look up which game libraries are missing for selected gamedir and download them from this repository, optionally download the game files from ModDB and Steam, apply patches, have a beautiful GUI......
- [ ] Cache object files for faster rebuilds.
- [ ] Make this run daily? Bi-weekly?
