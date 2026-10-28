# Hybrid cheat manager — design baseline

Status: **design only; not yet an FPGA implementation**.

## Goal
Use the existing GBA cheat engine while providing both SD-card-imported cheats and eventual on-device hexadecimal entry and per-game selection. Preserve upstream support and avoid changing `main` until tested.

## Confirmed upstream contract
- Existing text `.cht` and packed `.chtbin` readers, with filenames such as `Game.gba.cht`.
- 32 hardware cheat entries; conditional pairs consume two entries; 16 ROM patch slots.
- Existing overlay displays names supplied by `.cht`.
- Enabled flags are resolved by the text loader. `.chtbin` contains decoded enabled entries only.
- Unsupported/encrypted code types must not be interpreted as raw writes.
- Cheating is implemented independently of any on-device entry screen; no claims that the Pocket menu can already edit files.

## Proposed architecture
1. **Import**: Consume existing `.cht` format for baseline interoperability. A desktop helper will validate/normalize codes and produce named `.cht` files.
2. **Profile model**: Sidecar JSON for desktop/tooling with schema version, ROM identity (hash + display name), cheat IDs, source format/version, original input lines, descriptions, enabled flags, and validation reports. Never feed JSON directly to existing FPGA loader.
3. **On-device editing (research spike)**: Determine viable controls for hexadecimal text entry and persistent writes through APF/bridge without disturbing GBA timing. An overlay-only proof of concept should precede a full editor.
4. **Execution**: Reuse upstream loader and cheat table; no new memory-interception implementation until clearly required.
5. **Encryption**: Decoder implementations must be version-specific and tested against known vectors. Unsupported encrypted GameShark/Action Replay codes are rejected, not silently accepted.

## First engineering gates
- [ ] Unmodified fork builds and runs on Pocket hardware.
- [ ] Existing `.cht` file applies a visible cheat and overlay retains its name.
- [ ] Data slot/bridge and SD write feasibility assessed for on-device persistence.
- [ ] Desktop profile-to-`.cht` round trip validated with unit tests.
- [ ] Menu input prototype built; implementation and resource/timing effects measured.
- [ ] Full hardware regression (ROM/cart, save support, RTC, video, audio).

## Proposed profile file (desktop-side only)
```json
{
  "schema_version": 1,
  "game": {"name": "Example Game", "sha256": "<64-hex ROM digest>"},
  "cheats": [
    {
      "id": "example-health",
      "name": "Example health cheat",
      "format": "codebreaker-raw",
      "codes": ["3200E924 0096"],
      "enabled": true
    }
  ]
}
```

This example is illustrative; addresses and values must be validated against the specific ROM before hardware use.

## Compatibility rules
- Enabled cheat groups are atomic; never partially truncate conditional sequences.
- Preserve input ordering.
- Cap decoded entries and ROM patches at upstream limits.
- Preserve original ROM unchanged and never include copyrighted ROMs in the repository.
- UI/profile changes cannot imply support for unsupported cheat opcodes.
