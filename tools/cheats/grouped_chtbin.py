"""Version 2 grouped cheat binary format, desktop-only codec.

This module intentionally does not change the default v1 converter or FPGA
loader. V2 files MUST NOT be fed to the existing v1-only hardware loader.

Header (16 bytes): GBAC, version=2, flags=0, entry_count uint16 LE,
group_count uint16 LE, six reserved zero bytes.
Entry (16 bytes): legacy operation word with group ID in byte 13 (bits
111:104); all other reserved bits remain zero. Group IDs are zero-based.
"""
from __future__ import annotations

from dataclasses import dataclass

MAGIC = b"GBAC"
VERSION = 2
HEADER_SIZE = 16
ENTRY_SIZE = 16
MAX_ENTRIES = 32
GROUP_SHIFT = 104
GROUP_MASK = 0xFF << GROUP_SHIFT
LEGACY_RESERVED_MASK = (0xFFFFFFFF << 32) | (((1 << 24) - 1) << 104)


@dataclass(frozen=True)
class GroupedEntry:
    word: int
    group_id: int


def pack(entries: list[GroupedEntry], group_count: int) -> bytes:
    if not 0 <= group_count <= 32:
        raise ValueError("group count must be 0..32")
    if len(entries) > MAX_ENTRIES:
        raise ValueError("too many entries")
    if group_count == 0 and entries:
        raise ValueError("entries require a group")
    out = bytearray(MAGIC + bytes((VERSION, 0))
                    + len(entries).to_bytes(2, "little")
                    + group_count.to_bytes(2, "little") + bytes(6))
    previous = -1
    for entry in entries:
        if not 0 <= entry.word < (1 << 128) or entry.word & LEGACY_RESERVED_MASK:
            raise ValueError("invalid or reserved operation bits")
        if not 0 <= entry.group_id < group_count:
            raise ValueError("group ID out of range")
        if entry.group_id < previous:
            raise ValueError("group IDs must be nondecreasing")
        previous = entry.group_id
        out += (entry.word | (entry.group_id << GROUP_SHIFT)).to_bytes(16, "little")
    return bytes(out)


def unpack(blob: bytes) -> tuple[list[GroupedEntry], int]:
    if len(blob) < HEADER_SIZE or blob[:4] != MAGIC or blob[4] != VERSION:
        raise ValueError("not a v2 grouped cheat file")
    if blob[5] or any(blob[10:16]):
        raise ValueError("unsupported header flags or reserved bytes")
    count = int.from_bytes(blob[6:8], "little")
    groups = int.from_bytes(blob[8:10], "little")
    if count > MAX_ENTRIES or groups > 32 or len(blob) != HEADER_SIZE + count * ENTRY_SIZE:
        raise ValueError("invalid counts or truncated/trailing entries")
    entries = []
    for i in range(count):
        word = int.from_bytes(blob[16 + i * 16:32 + i * 16], "little")
        group_id = (word & GROUP_MASK) >> GROUP_SHIFT
        operation = word & ~GROUP_MASK
        if operation & LEGACY_RESERVED_MASK or group_id >= groups:
            raise ValueError("invalid entry")
        entries.append(GroupedEntry(operation, group_id))
    if any(a.group_id > b.group_id for a, b in zip(entries, entries[1:])):
        raise ValueError("unordered group IDs")
    return entries, groups
