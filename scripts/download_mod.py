#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# Mini client for hlsdk-mega-build
# Intended to be compatible with Python 3.6+
import argparse
import hashlib
import io
import json
import platform
import sys
import urllib.request
import zipfile
from pathlib import Path

DEFAULT_MANIFEST_URL = (
	"https://github.com/FWGS/hlsdk-mega-build/releases/download/continuous/manifest.json"
)
SUPPORTED_VERSION = 1

# we're going to create the file with the build info, so that we can handle updates
BUILD_INFO_FILENAME = ".mod_build_info.json"

def log(s):
	print(s)

def err(s):
	print(s, file=sys.stderr)

def detect_platform():
	system = platform.system().lower()
	machine = platform.machine().lower()

	# need to normalize Python's system names to library_naming convention
	# unknown will be passed as verbatim in hopes that it will work
	os_map = {
		"windows": "win32",
		"darwin": "apple"
	}

	arch_map = {
		"x86_64": "amd64",
		"i686": "i386",
		"aarch64": "arm64",
		"armv7l": "armhf",
	}

	os_key = os_map.get(system) or system
	arch_key = arch_map.get(machine) or machine

	return f"{os_key}-{arch_key}"

def fetch_json(url):
	with urllib.request.urlopen(url) as r:
		return json.load(r)

def fetch_bytes(url):
	with urllib.request.urlopen(url) as r:
		return r.read()

def load_local_build_info(gamedir):
	path = gamedir / BUILD_INFO_FILENAME
	if not path.is_file():
		return None
	try:
		return json.loads(path.read_text())
	except (OSError, json.JSONDecodeError):
		return None

def save_local_build_info(gamedir, info):
	(gamedir / BUILD_INFO_FILENAME).write_text(json.dumps(info, indent=2, sort_keys=True))

def uninstall_recorded_files(install_root, files):
	# uninstallation procedure. We don't touch user modified files.
	pruned_dirs = set()

	for entry in files:
		rel = entry.get("path")
		recorded_sha = entry.get("sha256")

		if not rel or not recorded_sha:
			continue

		target = (install_root / rel).resolve()
		# Refuse to follow paths that escape install_root.
		try:
			target.relative_to(install_root)
		except ValueError:
			err(f"refusing to delete out-of-tree path: {rel}")
			continue
		if not target.is_file():
			continue

		actual = hashlib.sha256(target.read_bytes()).hexdigest()
		if actual != recorded_sha:
			err(f"keeping locally modified file: {rel}")
			continue

		log(f"removing: {rel}")
		target.unlink()
		pruned_dirs.add(target.parent)

	for d in sorted(pruned_dirs, key=lambda p: len(p.parts), reverse=True):
		try:
			d.rmdir()
			log(f"removed empty directory: {d}")
		except OSError:
			pass

def extract_and_record(blob, install_root):
	# installation procedure, unpack the archive and save the files list
	files = []
	with zipfile.ZipFile(io.BytesIO(blob)) as zf:
		for info in zf.infolist():
			if info.is_dir():
				continue

			data = zf.read(info)
			target = install_root / info.filename
			target.parent.mkdir(parents=True, exist_ok=True)
			target.write_bytes(data)
			files.append({
				"path": info.filename,
				"sha256": hashlib.sha256(data).hexdigest(),
			})

	return files


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("gamedir", help="Mod gamedir name (valve, gearbox, etc)")
	parser.add_argument("--platform", dest="plat", default=None, help="Platform key <os>-<arch>; defaults to current host")
	parser.add_argument("--manifest-url", default=DEFAULT_MANIFEST_URL, help="URL of manifest.json")
	parser.add_argument("--install-root", default=".", help="Parent directory the gamedir lives under")
	parser.add_argument("--force", action="store_true", help="Download even if local tree matches manifest")
	args = parser.parse_args()

	plat = args.plat or detect_platform()
	install_root = Path(args.install_root).resolve()
	gamedir_path = install_root / args.gamedir

	manifest = fetch_json(args.manifest_url)
	if manifest.get("version") != SUPPORTED_VERSION:
		err(f"unsupported manifest version: {manifest.get('version')!r} (expected {SUPPORTED_VERSION})")
		return 2

	mod = manifest.get("mods", {}).get(args.gamedir)
	if mod is None:
		err(f"gamedir {args.gamedir!r} not present in manifest")
		return 3

	build = mod.get("builds", {}).get(plat)
	if build is None:
		err(f"no build for {args.gamedir} on {plat}")
		return 4

	remote_source = build.get("source") or {}
	remote_tree = remote_source.get("tree")
	remote_sha = build["sha256"]
	filename = build["filename"]

	local = load_local_build_info(gamedir_path) if gamedir_path.is_dir() else None
	if not args.force and local and remote_tree:
		prev = (local.get("source") or {}).get("tree")
		prev_plat = local.get("platform")
		if prev == remote_tree and prev_plat == plat:
			log(
				f"{args.gamedir}/{plat}: tree {remote_tree[:12]} unchanged, "
				f"skipping"
			)
			return 0

	# zip is published next to manifest.json in the same release
	asset_url = args.manifest_url.rsplit("/", 1)[0] + "/" + filename
	log(f"downloading {asset_url}")
	blob = fetch_bytes(asset_url)

	actual_sha = hashlib.sha256(blob).hexdigest()
	if actual_sha != remote_sha:
		err(
			f"sha256 mismatch for {filename}: got {actual_sha}, "
			f"expected {remote_sha}"
		)
		return 5

	# Remove files from the previous install before laying down the new ZIP.
	# ZIPs from build_common.sh contain the gamedir as the top-level entry,
	# so we extract into the install root, not into gamedir_path itself.
	if local:
		uninstall_recorded_files(install_root, local.get("files") or [])

	install_root.mkdir(parents=True, exist_ok=True)
	installed_files = extract_and_record(blob, install_root)

	save_local_build_info(gamedir_path, {
		"gamedir": args.gamedir,
		"platform": plat,
		"filename": filename,
		"sha256": remote_sha,
		"source": remote_source,
		"manifest_build": manifest.get("build"),
		"files": installed_files,
	})

	tree_short = remote_tree[:12] if remote_tree else "unknown"
	log(f"installed {args.gamedir}/{plat} @ tree {tree_short}")
	return 0

if __name__ == "__main__":
	sys.exit(main())
