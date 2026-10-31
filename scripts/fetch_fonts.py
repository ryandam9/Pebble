#!/usr/bin/env python3
"""Install and verify Pebble's offline font assets during bootstrap.

Both families are licensed under SIL Open Font License 1.1 (see third_party/fonts).
A font file is downloaded only when absent or its pinned Git blob checksum differs.
The files are packaged by Flutter, so the installed app never needs font networking.
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
from urllib.error import URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "fonts"
BASE = "https://raw.githubusercontent.com/google/fonts/main/"

# Git blob object IDs correspond to the official google/fonts repository.
FONTS = {
    "PlusJakartaSans-Regular.ttf": (
        "ofl/plusjakartasans/PlusJakartaSans[wght].ttf",
        "0cb13a998ed525ba226d911b10d6c4c4f923a961",
    ),
    "PlusJakartaSans-Italic.ttf": (
        "ofl/plusjakartasans/PlusJakartaSans-Italic[wght].ttf",
        "82b042caaaf271beb9e3cbd95ba4741a3d5b8926",
    ),
    "Fraunces-Regular.ttf": (
        "ofl/fraunces/Fraunces[SOFT,WONK,opsz,wght].ttf",
        "8210f9488d3c732359a9292dd09aca3f2bae830e",
    ),
    "Fraunces-Italic.ttf": (
        "ofl/fraunces/Fraunces-Italic[SOFT,WONK,opsz,wght].ttf",
        "2ddf59a11b89a3d6b2816ea6ae7965026c08143a",
    ),
}

def git_blob_sha(data: bytes) -> str:
    return hashlib.sha1(
        b"blob " + str(len(data)).encode("ascii") + b"\0" + data
    ).hexdigest()


def install() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, (source, expected) in FONTS.items():
        output = OUTPUT / name
        if output.exists() and git_blob_sha(output.read_bytes()) == expected:
            print(f"[fonts] verified {name}")
            continue
        address = BASE + "/".join(quote(part, safe="") for part in source.split("/"))
        print(f"[fonts] fetching {name}")
        request = Request(address, headers={"User-Agent": "Pebble-Flutter-font-bootstrap"})
        try:
            with urlopen(request, timeout=35) as response:
                content = response.read()
        except (OSError, URLError) as error:
            raise SystemExit(
                f"Unable to fetch {name}: {error}. "
                "An internet connection is required once during setup."
            ) from error
        actual = git_blob_sha(content)
        if actual != expected:
            raise SystemExit(
                f"Font verification failed for {name}. "
                f"Expected {expected}, received {actual}. "
                "Google Fonts might have updated its release; review the change before updating the pin."
            )
        temporary = output.with_name(output.name + ".partial")
        temporary.write_bytes(content)
        os.replace(temporary, output)
        print(f"[fonts] ready {name} ({len(content)} bytes)")


if __name__ == "__main__":
    install()
