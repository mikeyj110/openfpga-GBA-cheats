# Cheat group identity and execution gating — design checkpoint

## Verified current behavior

- Version 1 `.chtbin` uses a 16-byte header and 16-byte entries.
- Header bytes 6–7 count **entries**, not named cheat groups.
- The binary loader reconstructs only the currently consumed operation fields and
  discards reserved entry bytes. It cannot transport group IDs as-is.
- The text loader counts named groups separately, but the engine receives only
  128-bit operation words without group identity.
- The engine's conditional operations apply to the immediately following entry.
- The runtime menu mask is currently display-only; it must not be described as
  execution gating.

## Proposed backward-compatible design (not yet implemented)

1. Define a version 2 `.chtbin` header with explicit group count, and a
   per-entry group ID in a currently reserved entry byte. Keep version 1
   decoding supported with legacy execution behavior.
2. Extend the binary loader's byte retention and output construction to
   preserve the group ID. Version 1 files must not accidentally receive
   fabricated per-group semantics.
3. Extend the text loader to tag every emitted operation with its originating
   group, including both halves of a conditional pair.
4. Add group metadata to the engine's stored entries and a synchronized
   runtime enable mask. Skip disabled groups before any bus read/write;
   preserve conditional pairing and reset skip state at group boundaries.
5. Trace and separately gate ROM patches, which use a different path.
6. Add tests for v1 compatibility, v2 round trip, multi-entry groups,
   conditional boundaries, reload, all 32 entries and ROM patch behavior.

## Constraints

- Do not change the existing version 1 format in place.
- Do not reorder or filter conditional pairs during packing.
- Do not connect the display-only runtime mask to execution until all entry
  paths carry correct group identity.
- Verify simulation, synthesis fit and timing before distributing a core.
