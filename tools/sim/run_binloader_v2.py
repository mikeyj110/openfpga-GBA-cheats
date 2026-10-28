#!/usr/bin/env python3
"""Focused v2 FPGA loader regression using the existing consumer-model bench.

Run inside the pocket-sim container:
    python3 tools/sim/run_binloader_v2.py
"""
from __future__ import annotations

import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "cheats"))
import grouped_chtbin as v2

BUILD = ROOT / "build" / "sim"
BUILD.mkdir(parents=True, exist_ok=True)
TB = BUILD / "tb_cheat_binloader_v2"
SOURCES = ["tools/sim/tb_cheat_binloader.sv",
           "tools/sim/gba_cheats_model.sv",
           "src/fpga/core/cheat_binloader.sv"]


def run(blob: bytes, expected: list[v2.GroupedEntry], groups: int, gap: int) -> None:
    path = BUILD / "fixture-v2.chtbin"
    path.write_bytes(blob)
    output = subprocess.run(["vvp", str(TB), f"+f={path}", f"+gap={gap}"],
                            cwd=ROOT, capture_output=True, text=True, check=True).stdout
    actual = [int(x, 16) for x in re.findall(r"^WORD ([0-9a-f]{32})$", output, re.M)]
    want = [e.word | (e.group_id << 104) for e in expected]
    if actual != want:
        raise AssertionError(f"v2 entries mismatch: {actual!r} != {want!r}\n{output}")
    match = re.search(r"TOTAL bytes=(\d+) declared=(\d+) entries=(\d+) "
                      r"rejected=(\d+) malformed=(\d+) stored=(\d+)", output)
    if not match:
        raise AssertionError("missing summary: " + output)
    size, declared, entries, rejected, malformed, stored = map(int, match.groups())
    if (size, declared, entries, rejected, malformed, stored) != (
            len(blob), groups, len(expected), 0, 0, len(expected)):
        raise AssertionError("unexpected counters: " + output)


def main() -> None:
    subprocess.run(["iverilog", "-g2012", "-s", "tb", "-o", str(TB), *SOURCES],
                   cwd=ROOT, check=True)
    # Three operations, two groups. The first group contains two operations,
    # representing a compare/write pair, whose adjacency must remain intact.
    entries = [v2.GroupedEntry(0x101, 0),
               v2.GroupedEntry(0x202, 0),
               v2.GroupedEntry(0x303, 1)]
    blob = v2.pack(entries, 2)
    for gap in (0, 1, 4):
        run(blob, entries, 2, gap)
        print(f"ok v2 grouped entries gap={gap}")
    run(v2.pack([], 0), [], 0, 0)
    print("ok v2 empty")

    # Reject an entry whose ID is equal to the declared group count.
    bad = bytearray(blob)
    bad[16 + 13] = 2
    path = BUILD / "invalid-group-v2.chtbin"
    path.write_bytes(bad)
    output = subprocess.run(["vvp", str(TB), f"+f={path}", "+gap=0"],
                            cwd=ROOT, capture_output=True, text=True, check=True).stdout
    actual = [int(x, 16) for x in re.findall(r"^WORD ([0-9a-f]{32})$", output, re.M)]
    expected = [entries[1].word, entries[2].word | (1 << 104)]
    if actual != expected or "declared=2 entries=2 rejected=1 malformed=1 stored=2" not in output:
        raise AssertionError("invalid group ID was not rejected:\\n" + output)
    print("ok v2 invalid group ID rejected")



    # A v1 file must still load the same operations, with zero group tags.
    import run_binloader as legacy
    old_entries = legacy.TABLE[:3]
    old_blob = legacy.stream(old_entries)
    old_path = BUILD / "fixture-legacy-v1.chtbin"
    old_path.write_bytes(old_blob)
    old_output = subprocess.run(["vvp", str(TB), f"+f={old_path}", "+gap=0"],
                                cwd=ROOT, capture_output=True, text=True, check=True).stdout
    old_actual = re.findall(r"^WORD ([0-9a-f]{32})$", old_output, re.M)
    if old_actual != legacy.words(old_entries) or (
            "declared=3 entries=3 rejected=0 malformed=0 stored=3" not in old_output):
        raise AssertionError("v1 regression:\\n" + old_output)
    print("ok v1 compatibility")

    # A group boundary may not merge adjacent operations into one group.
    boundary = [v2.GroupedEntry(0x101, 0), v2.GroupedEntry(0x202, 0),
                v2.GroupedEntry(0x303, 1), v2.GroupedEntry(0x404, 2)]
    run(v2.pack(boundary, 3), boundary, 3, 0)
    print("ok v2 group boundaries")

if __name__ == "__main__":
    main()
