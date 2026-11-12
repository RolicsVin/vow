#!/usr/bin/env python3
"""
Downloads the official Windows *embeddable* Python and prepares it for the addon:
  addons/python_bridge/runtime/windows/

  python tools/setup_windows_runtime.py                       # Python 3.12.8
  python tools/setup_windows_runtime.py --version 3.12.8 -r requirements.txt

Works on any OS (pip is told to fetch win_amd64 wheels). Packages without a
prebuilt win_amd64 wheel cannot be installed this way.
"""
import argparse
import io
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

ADDON = Path(__file__).resolve().parent.parent
TARGET = ADDON / "runtime" / "windows"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", default="3.12.8", help="CPython version (must have an embeddable build)")
    ap.add_argument("-r", "--requirements", help="requirements.txt to install into the runtime")
    ap.add_argument("--keep", action="store_true", help="do not wipe the existing runtime first")
    args = ap.parse_args()

    ver = args.version
    short = ".".join(ver.split(".")[:2])
    url = f"https://www.python.org/ftp/python/{ver}/python-{ver}-embed-amd64.zip"

    if TARGET.exists() and not args.keep:
        shutil.rmtree(TARGET)
    TARGET.mkdir(parents=True, exist_ok=True)

    print(f"Downloading {url}")
    with urllib.request.urlopen(url) as resp:
        data = resp.read()
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        z.extractall(TARGET)

    # Enable site-packages: embeddable Python ignores everything not listed in ._pth
    pth = next(TARGET.glob("python*._pth"))
    lines = pth.read_text().splitlines()
    out = []
    for line in lines:
        if line.strip() == "#import site":
            line = "import site"
        out.append(line)
        if line.strip() == "." and "Lib/site-packages" not in lines:
            out.append("Lib/site-packages")
    pth.write_text("\n".join(out) + "\n")

    site = TARGET / "Lib" / "site-packages"
    site.mkdir(parents=True, exist_ok=True)

    if args.requirements:
        subprocess.check_call([
            sys.executable, "-m", "pip", "install",
            "--target", str(site),
            "--platform", "win_amd64",
            "--python-version", short,
            "--implementation", "cp",
            "--only-binary=:all:",
            "--upgrade",
            "-r", args.requirements,
        ])

    (ADDON / "runtime" / ".gdignore").touch()
    print(f"Done: {TARGET}")


if __name__ == "__main__":
    main()
