#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Convert a versioned desktop cheat profile into the core's .cht format."""
import argparse
import hashlib
import json
import re
from pathlib import Path

HEX = re.compile(r"^[0-9A-Fa-f]+$")
FORMATS = {"codebreaker-raw": (4, 12), "gameshark-raw": (8, 16), "action-replay-raw": (8, 16)}
MAX_NAME = 80

def normalize_line(line, fmt):
    if not isinstance(line, str):
        raise ValueError("code line must be a string")
    parts = re.split(r"[\s+:]+", line.strip())
    if len(parts) == 1 and len(parts[0]) == FORMATS[fmt][1]:
        parts = [parts[0][:8], parts[0][8:]]
    if len(parts) != 2 or len(parts[0]) != 8 or len(parts[1]) != FORMATS[fmt][0]:
        raise ValueError(f"invalid {fmt} code length: {line!r}")
    if not all(HEX.fullmatch(p) for p in parts):
        raise ValueError(f"invalid hexadecimal code: {line!r}")
    return "+".join(p.upper() for p in parts)

def convert(profile):
    if not isinstance(profile, dict) or profile.get("schema_version") != 1:
        raise ValueError("expected schema_version 1")
    game = profile.get("game")
    if not isinstance(game, dict) or not isinstance(game.get("name"), str) or not game["name"].strip():
        raise ValueError("game.name is required")
    digest = game.get("sha256")
    if digest is not None and (not isinstance(digest, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", digest)):
        raise ValueError("game.sha256 must be a 64-character hex digest")
    cheats = profile.get("cheats")
    if not isinstance(cheats, list):
        raise ValueError("cheats must be an array")
    out = []
    ids = set()
    for i, cheat in enumerate(cheats):
        if not isinstance(cheat, dict):
            raise ValueError(f"cheat {i} must be an object")
        cid, name, fmt, codes, enabled = (cheat.get(k) for k in ("id", "name", "format", "codes", "enabled"))
        if not isinstance(cid, str) or not cid or cid in ids:
            raise ValueError(f"cheat {i}: missing or duplicate id")
        ids.add(cid)
        if not isinstance(name, str) or not name.strip() or len(name) > MAX_NAME or any(ord(ch) < 32 or ch == '"' for ch in name):
            raise ValueError(f"cheat {i}: invalid name")
        if fmt not in FORMATS:
            raise ValueError(f"cheat {i}: unsupported format {fmt!r}; encrypted formats require a decoder")
        if not isinstance(enabled, bool) or not isinstance(codes, list) or not codes:
            raise ValueError(f"cheat {i}: enabled must be boolean and codes must be nonempty array")
        normalized = [normalize_line(c, fmt) for c in codes]
        out += [f'cheat{i}_desc = "{name}"', f'cheat{i}_code = "{"+".join(normalized)}"', f'cheat{i}_enable = {str(enabled).lower()}', ""]
    return ("\n".join(out) + "\n").encode("utf-8")

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("profile", type=Path)
    ap.add_argument("-o", "--output", type=Path, required=True)
    ap.add_argument("--rom", type=Path, help="verify optional game.sha256 against ROM")
    args = ap.parse_args()
    profile = json.loads(args.profile.read_text(encoding="utf-8"))
    if args.rom:
        expected = profile.get("game", {}).get("sha256")
        if not expected:
            ap.error("profile lacks game.sha256")
        h = hashlib.sha256()
        with args.rom.open("rb") as f:
            for block in iter(lambda: f.read(1024 * 1024), b""):
                h.update(block)
        if h.hexdigest().lower() != expected.lower():
            ap.error("ROM SHA-256 does not match profile")
    result = convert(profile)
    args.output.write_bytes(result)
    print(f"Wrote {args.output} ({len(profile['cheats'])} cheat groups)")

if __name__ == "__main__":
    main()
