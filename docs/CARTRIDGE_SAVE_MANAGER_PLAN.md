# Physical cartridge save manager — implementation plan

Status: design/inspection only. No RTL changes, no cartridge writes enabled.

## Existing paths (feature/hybrid-cheat-manager)

- `src/fpga/core/core_top.sv`: PSRAM die 1 holds SD-ROM save data.
- `save_data_loader` accepts bridge writes into PSRAM die 1 during boot.
- `save_data_unloader` serves bridge reads from PSRAM die 1 for SD save writeback.
- Physical-cartridge save operations use `cart_save_req/rnw/addr/din/dout/done` and a separate EEPROM serial path (`cart_eeprom_*`).
- Cartridge mode intentionally advertises zero save size to APF and bypasses waiting for an SD save.

Do **not** just advertise a nonzero save size in cartridge mode: that may change normal Pocket/APF save lifecycle and does not prove cartridge read/write safety.

## Proposed staged implementation

### Stage 0 — characterize, no hardware writes
1. Trace physical cart save bus arbitration, SRAM/FLASH/EEPROM detection, and save timing.
2. Identify how APF can request a user-selected file and where a read-only export can be exposed.
3. Establish correct save sizes (including Golden Sun's 64 KiB FLASH), byte order, and error signaling.
4. Create simulation fixtures for save-memory operations and failure conditions.

### Stage 1 — read-only export
1. Add a controller that reads cartridge save through the existing cart interface while game execution is safely paused.
2. Buffer into PSRAM, expose a read-only APF data slot or other documented host-supported export path.
3. Verify byte-for-byte against an independent cartridge backup; report checksum/hash and size.
4. Reject unsupported save devices, failed probes, and partial reads.

### Stage 2 — import validation without cartridge write
1. Accept selected .sav via a dedicated data slot; stage bytes in PSRAM.
2. Validate length, device compatibility, and game identity when available.
3. Read back staged data and compare with source. No cart writes.

### Stage 3 — explicit restore
1. Require explicit in-core confirmation and independent backup.
2. Pause GBA, ensure exclusive access to cartridge save bus.
3. Implement device-specific writes: SRAM, FLASH command sequences/erase sectors, EEPROM serial protocol.
4. Read back all bytes, compare, report errors, and do not claim success if verification fails.
5. Test with disposable hardware before Golden Sun cartridge.

## Safety gates

- Default is read-only; no automatic write on launch, reset, or state restore.
- Never use an old .sta as proof that an imported .sav was applied.
- No changes to cheat pipeline or existing SD save behavior.
- Keep core folder exactly `author.shortname` (currently `mikeyj110.GBA`).
- Preserve current working bitstream until simulation and compile tests pass.

## Stage 0 code inspection findings (2026-10-28)

In `src/fpga/core/core_top.sv`:

- Lines 350–409 instantiate `data_loader` / `data_unloader` using bridge address prefix `0x2`, backed by PSRAM die 1. This path belongs to SD-ROM saves, **not** directly to cartridge save storage.
- Lines 948–952 use 64 KiB default save size and 128 KiB when `det_flash_1m`; this is SD save sizing and not a cartridge device-identification guarantee.
- Lines 2097–2107 use `cart_eeprom_bridge` for EEPROM transactions.
- Lines 2109–2127 use `cart_bus_arbiter` to serialize ROM, save, EEPROM, and IO requests. The existing save port is driven by the running GBA, so an independent manager needs its own arbitration source and exclusive-access condition.
- Lines 2129–2170 instantiate `gba_cart_controller`, which exposes byte-wide `save_req/save_addr/save_rnw/save_din/save_dout/save_done` and separate EEPROM signals. FLASH protocol commands and EEPROM serial transactions must be handled correctly, not treated as a flat byte array.

**Design implication:** do not connect the SD `.sav` loader directly to `ctl_save_*`. First inspect `cart_bus_arbiter`, `gba_cart_controller`, and the save device implementation, and establish a documented host export/import mechanism. In particular, a raw FLASH save backup requires correct flash-bank selection and command sequencing; a byte read alone may not capture all banks.

No RTL or hardware behavior changed in this inspection.
