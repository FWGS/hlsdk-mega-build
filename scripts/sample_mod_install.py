#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Sample mod installer from hlsdk-mega-build's manifest.
#
# Intended to be compatible with Python 3.6+
#
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
MODDB_DOWNLOAD = SCRIPT_DIR / "moddb-download.sh"
SFX_FACTORY_EXTRACT = SCRIPT_DIR / "sfx-factory-extract.sh"
DOWNLOAD_MOD = SCRIPT_DIR / "download_mod.py"

DEFAULT_MANIFEST_URL = (
	"https://github.com/FWGS/hlsdk-mega-build/releases/download/continuous/manifest.json"
)
SUPPORTED_VERSION = 1

BROWSER_UA = "Mozilla/5.0 (X11; Linux x86_64; rv:153.0) Gecko/20100101 Firefox/153.0"

def log(s):
	print(s, flush=True)

def err(s):
	print(s, file=sys.stderr, flush=True)

def load_manifest(url):
	# a local copy of manifest.json is handy for testing
	path = Path(url)
	if path.is_file():
		with open(str(path)) as f:
			return json.load(f)
	with urllib.request.urlopen(url) as r:
		return json.load(r)

def download_content(game, workdir):
	method = game["dl_method"]

	if method == "moddb":
		# the script names the file after the CDN filename, so give it an
		# empty directory and pick up whatever appears there
		dldir = workdir / "moddb"
		dldir.mkdir()
		subprocess.run([str(MODDB_DOWNLOAD), game["dl_url"], str(dldir)], check=True)
		files = list(dldir.iterdir())
		if len(files) != 1:
			raise RuntimeError(f"expected one downloaded file, got {files}")
		return files[0]

	if method in ("get", "get_with_redirect"):
		# urllib follows redirects by default, which also covers plain get
		url = game["dl_url"]
		name = Path(urllib.parse.unquote(urllib.parse.urlsplit(url).path)).name
		target = workdir / (name or "download.bin")
		req = urllib.request.Request(url)
		if game.get("need_browser_ua"):
			req.add_header("User-Agent", BROWSER_UA)
		log(f"downloading {url}")
		with urllib.request.urlopen(req) as r, open(target, "wb") as f:
			shutil.copyfileobj(r, f)
		return target

	raise RuntimeError(f"dl_method {method!r} is not handled here")

def verify_sha256(path, expected):
	h = hashlib.sha256()
	with open(str(path), "rb") as f:
		for chunk in iter(lambda: f.read(1 << 20), b""):
			h.update(chunk)
	actual = h.hexdigest()
	if actual != expected:
		raise RuntimeError(
			f"sha256 mismatch for {path.name}: got {actual}, expected {expected}\n"
			"the download may have been replaced upstream, refusing to unpack"
		)
	log(f"sha256 OK: {path.name}")

def unpack(game, archive, dest):
	method = game.get("unpack_method")
	dest.mkdir()

	# tool invocations that unpack `archive` into the `dest` directory
	commands = {
		"unzip":       ["unzip", "-q", str(archive), "-d", str(dest)],
		# a1ba: 7zip technically supports unrar but quite often produces corrupted/empty files
		"unrar":       ["unrar", "x", "-idq", str(archive), str(dest) + "/"],
		"7z":          ["7z", "x", "-y", f"-o{dest}", str(archive)],
		"innoextract": ["innoextract", "-s", "-d", str(dest), str(archive)],
		"sfx_factory": [str(SFX_FACTORY_EXTRACT), str(archive), str(dest)],
	}

	if method not in commands:
		raise RuntimeError(f"unpack_method {method!r} has no unpacker yet")
	subprocess.run(commands[method], check=True)

def copy_tree(src, dst):
	dst.mkdir(parents=True, exist_ok=True)
	for item in src.iterdir():
		target = dst / item.name
		if item.is_dir():
			copy_tree(item, target)
		else:
			shutil.copy2(item, target)

def install_content(game, unpacked, install_root):
	unpack_dir = game.get("unpack_root")
	src = unpacked / unpack_dir if unpack_dir else unpacked
	if not src.is_dir():
		raise RuntimeError(f"unpack_root {unpack_dir!r} not found in archive")

	unpack_to = game.get("unpack_to")
	if unpack_to: # the archive carries no gamedir folder, src IS the gamedir content
		target = install_root / unpack_to
		log(f"installing content -> {target}")
		copy_tree(src, target)
		return

	dirs = game.get("dir")
	if not dirs:
		raise RuntimeError("entry has no dir metadata, don't know what to install")

	for d in dirs:
		target = install_root / d
		log(f"installing {d} -> {target}")
		copy_tree(src / d, target)

def list_mods(manifest):
	mods = manifest.get("mods", {})
	width = max(map(len, mods), default=0)
	for name in sorted(mods):
		games = mods[name].get("games")
		if not games:
			log(f"{name:<{width}}  (no games metadata)")
			continue
		title = games[0].get("title", "")
		method = games[0].get("dl_method", "none")
		log(f"{name:<{width}}  {title} [{method}]")

def install_gamelibs(name, install_root, plat, manifest_url):
	cmd = [sys.executable, str(DOWNLOAD_MOD), name, "--install-root", str(install_root)]
	if plat:
		cmd += ["--platform", plat]
	if manifest_url:
		cmd += ["--manifest-url", manifest_url]
	subprocess.run(cmd, check=True)

def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("mod", nargs="?", default=None, help="Mod name, as keyed in manifest.json mods{}")
	parser.add_argument("--list", action="store_true", dest="list_mods", help="List the mods available in the manifest and exit")
	parser.add_argument("--manifest-url", default=DEFAULT_MANIFEST_URL, help="URL (or local path, for testing) of manifest.json")
	parser.add_argument("--install-root", default=".", help="Parent directory the gamedir lives under")
	parser.add_argument("--platform", dest="plat", default=None, help="Platform key <os>-<arch> for the game libraries, defaults to current host")
	parser.add_argument("--skip-content", action="store_true", help="Only install the game libraries")
	parser.add_argument("--skip-gamelibs", action="store_true", help="Only install the mod content")
	args = parser.parse_args()

	if not args.list_mods and not args.mod:
		parser.error("mod name is required unless --list is given")

	manifest = load_manifest(args.manifest_url)
	if manifest.get("version") != SUPPORTED_VERSION:
		err(f"unsupported manifest version: got {manifest.get('version')!r}, expected {SUPPORTED_VERSION}")
		return 2

	if args.list_mods:
		list_mods(manifest)
		return 0

	mod = manifest.get("mods", {}).get(args.mod)
	if mod is None:
		err(f"{args.mod!r} not found in manifest")
		return 3

	games = mod.get("games")
	if not games:
		err(f"{args.mod!r} has no games metadata")
		return 3

	game = games[0]

	install_root = Path(args.install_root).resolve()
	install_root.mkdir(parents=True, exist_ok=True)

	if not args.skip_content:
		method = game.get("dl_method", "none")
		if method == "steam":
			err(f"{args.mod!r} content comes from Steam, depotdownloader integration is undone")
		elif method == "none":
			err(f"{args.mod!r} has no downloadable content")
		else:
			with tempfile.TemporaryDirectory(prefix="mod-install-") as tmp:
				tmp = Path(tmp)
				archive = download_content(game, tmp)
				sha = game.get("dl_sha256sum")
				if sha:
					verify_sha256(archive, sha)
				else:
					err(f"warning: no dl_sha256sum for {args.mod!r}, skipping verification")
				unpacked = tmp / "unpacked"
				unpack(game, archive, unpacked)
				install_content(game, unpacked, install_root)

	if not args.skip_gamelibs:
		# download_mod.py refetches the manifest itself, only pass the URL
		# along when it points at something it can fetch
		url = args.manifest_url if not Path(args.manifest_url).is_file() else None
		install_gamelibs(args.mod, install_root, args.plat, url)

	return 0

if __name__ == "__main__":
	sys.exit(main())
