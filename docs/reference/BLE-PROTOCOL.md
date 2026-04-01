# BLE-protocol (samenvatting)

Alle details staan in code: `reference/panel-hopper-github/vendor/bk_light/display_session.py`. Hieronder een **compacte naslag**; bij twijfel altijd die file volgen.

**Zie ook**

- [IOS-BLE-SEQUENCES.md](IOS-BLE-SEQUENCES.md) — byte-volgordes en timing voor CoreBluetooth
- [PLATFORM-BLE.md](PLATFORM-BLE.md) — Windows / Linux / iOS-afwijkingen (MTU, writes)
- [16x32-HARDWARE.md](16x32-HARDWARE.md) — 16×32 alleen na meting op hardware
- [DISPLAY-DESIGN.md](DISPLAY-DESIGN.md) — wat past op 32×32, PNG vs GIF, kleur/contrast

## GATT

| Rol | UUID |
|-----|------|
| Write (commando’s + beeld) | `0000fa02-0000-1000-8000-00805f9b34fb` |
| Notify (ACK’s) | `0000fa03-0000-1000-8000-00805f9b34fb` |

## Handshake (statisch beeld / sessie)

Voorbeelden (hex):

- `HANDSHAKE_FIRST`: `08 00 01 80 0E 06 32 00`
- `HANDSHAKE_SECOND`: `04 00 05 80`
- ACK’s: o.a. `ACK_STAGE_ONE`, `ACK_STAGE_TWO`, `ACK_STAGE_THREE` (zie broncode)

De `32 00`-delen zijn gebonden aan de **huidige 32×32-aanname**; voor **16×32** zijn andere waarden mogelijk (nog niet in upstream vastgelegd).

## Stilstaand beeld (PNG)

1. Optioneel: animatie stoppen (`set_display_mode(1)` — static).
2. Handshake indien nog niet gedaan in deze sessie.
3. **`CMD_EDIT_END`**: `05 00 04 01 00` (iPixel: “edit end” vóór frame).
4. Frame schrijven met `build_frame(png_bytes)` — write met response, wacht op frame-ACK.

### `build_frame` — packetlay-out (iPixel / SendCore-achtig)

- `[0-1]` Totale lengte (little endian)
- `[2-3]` Datatype: `0x02,0x00` = image; `0x03,0x00` = GIF
- `[4]` Optie: `0x00` eerste deel, `0x02` vervolg
- `[5-8]` Datalengte (uint32 LE)
- `[9-12]` CRC32 over payload
- `[13]` Extra: `0x00` statisch, `0x02` GIF-animatie-indicator
- `[14]` Kanaal: `0x65`
- `[15+]` Ruwe PNG/GIF-bytes

## GIF

- Ruwe **GIF-bestandsdata** (niet per se per-frame PNG), vaak **geschaald naar 32×32**.
- **Chunking**: grote GIF’s in stukken van **12288 bytes (12 KB)** per chunk (uit iPixel APK-analyse in commentaar).
- Per chunk: wacht op ACK `05 00 03 00 01`; na laatste chunk: `05 00 03 00 03`.
- Daarna display modes (prepare/animate), zoals in README: o.a. `07 00 08 80 01 00 01` en `07 00 08 80 01 00 02`.

Zie ook repository-`README.md` sectie **GIF Protocol**.

## Paneelcommando’s (fragmenten uit bron)

Formaat vaak: lengte + command-id + payload. In code onder andere:

| Doel | Notitie in code |
|------|-----------------|
| Helderheid | `CMD_BRIGHTNESS` + byte 0–100 |
| Rotatie | `CMD_ROTATION` + 0–3 |
| Aan/uit | `CMD_ON_OFF` |
| Alles wissen | `CMD_DELETE_ALL` |
| Opslaan startup | `CMD_SAVE_PREPARE` / `CMD_SAVE_COMMIT` na `CMD_EDIT_END` |

Exacte bytes: `display_session.py` bovenin (`CMD_*` constanten).

## ACK’s voor commando’s

Notification handler herkent o.a. command-id’s in `[2:4]` (bytes op index 2–3) voor brightness, rotation, on/off, save, display mode, edit end, delete all — zie `AckWatcher.handler` in hetzelfde bestand.

## Timing (indicatief)

| Stap | Orde-grootte | Notitie |
|------|----------------|--------|
| Tussen handshake en volgende write | ~0,2 s | Default `delay` in `send_frame` |
| Na `CMD_EDIT_END` | ~0,05 s | Voor frame-write |
| ACK-timeout (handshake / frame) | 5 s | `wait_for_ack` |
| GIF: tussen BLE-segmenten | ~5 ms | Binnen één logische chunk |
| GIF: chunk-ACK wacht | tot 2 s | Per chunk |

Details: [IOS-BLE-SEQUENCES.md](IOS-BLE-SEQUENCES.md).

## PC-tool in dit project

Scripts: `tools/ble/send_to_panel.py` (PNG/GIF via Bleak), `tools/ble/generate_test_png.py` (32×32 test-PNG). Installeer `tools/ble/requirements.txt`. Zet `BK_LIGHT_ADDRESS` of `--address`. Standaard wachtijden in de CLI zijn gelijk aan `BleDisplaySession.send_png` (0,2 s) en `send_gif` (0,05 s); zie `tools/ble/README.md`.

**Tests vs. vendor:** `tests/test_ble_protocol.py` importeert `build_frame`, constanten en `AckWatcher` rechtstreeks uit `display_session.py`; één test bouwt de GIF-chunkheader opnieuw op volgens dezelfde rekenregels als `send_gif()` — bij wijzigingen in die loop moet die test mee worden gecontroleerd (geen tweede waarheid buiten de vendorfile).
