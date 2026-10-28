#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
  echo "ERROR: Install Icarus Verilog (iverilog and vvp) before running." >&2
  exit 127
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
iverilog -g2012 -s tb_cart_save_backup_reader -o "$tmp/backup_reader.vvp" \
  src/fpga/han/cart_save_backup_reader.sv \
  sim/han/tb_cart_save_backup_reader.sv
vvp "$tmp/backup_reader.vvp"
