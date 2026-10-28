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
    print("PASS gba_cheats VHDL analysis and elaboration (not behavioral simulation)")

if __name__ == "__main__":
    main()
