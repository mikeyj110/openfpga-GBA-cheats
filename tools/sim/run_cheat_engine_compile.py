#!/usr/bin/env python3
"""Compile the real GBA cheat engine with GHDL before enabling group gating.

This is an elaboration smoke test, NOT a behavioral proof of masking.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src/fpga/gba"
BUILD = ROOT / "build/sim/cheat_engine"

def main():
    BUILD.mkdir(parents=True, exist_ok=True)
    def run(*args):
        subprocess.run(["ghdl", *args], cwd=BUILD, check=True)
    run("-a", "--std=08", "--work=mem", str(SRC / "SyncFifo.vhd"))
    run("-a", "--std=08", str(SRC / "proc_bus_gba.vhd"))
    run("-a", "--std=08", str(SRC / "gba_cheats.vhd"))
    run("-e", "--std=08", "gba_cheats")
    print("PASS gba_cheats VHDL analysis and elaboration")
    run("-a", "--std=08", str(ROOT / "tools/sim/tb_cheat_group_gate.vhd"))
    run("-e", "--std=08", "tb_cheat_group_gate")
    result = subprocess.run(
        ["ghdl", "-r", "--std=08", "tb_cheat_group_gate",
         "--assert-level=error", "--stop-time=30us"],
        cwd=BUILD, capture_output=True, text=True, check=True)
    output = result.stdout + result.stderr
    print(output, end="")
    required = (
        "PASS group mask: group 0 disabled, group 1 enabled",
        "PASS disabled conditional cannot suppress next enabled group",
        "PASS enabled matching conditional pair",
        "PASS enabled nonmatching conditional pair",
    )
    missing = [marker for marker in required if marker not in output]
    if missing:
        raise RuntimeError("Behavioral bench ended before required checks: " + repr(missing))
    print("PASS grouped execution behavioral bench")

if __name__ == "__main__":
    main()
