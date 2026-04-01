# iOS — exacte byte-volgordes en timing (BK-Light / iPixel-achtig)

Bron: `reference/panel-hopper-github/vendor/bk_light/display_session.py`. Alle multi-byte integers **little-endian** (LE), tenzij anders vermeld.

## Notificaties (peripheral → central)

Abonneer op **FA03**. Payloads zijn **byte-identiek** aan onderstaande tabellen.

### Handshake (statisch beeld / sessie)

| Stap | Central → Write FA02 | Peripheral → Notify FA03 (ACK) |
|------|------------------------|----------------------------------|
| 1 | `08 00 01 80 0E 06 32 00` | `0C 00 01 80 81 06 32 00 00 01 00 01` (`ACK_STAGE_ONE`) |
| 2 | `04 00 05 80` | `08 00 05 80 0B 03 07 02` (`ACK_STAGE_TWO`) |

Na een volledig verzonden **PNG-frame** (write met response, zie hieronder) kan de panel **notify** sturen: `05 00 02 00 03` (`ACK_STAGE_THREE` / frame-ack in flow).

### Stilstaand PNG (typische volgorde)

1. Optioneel: `SET_DISPLAY_MODE` static — `07 00 08 80 01 00 01` (mode 1) om animatie te stoppen; dan **~200 ms** pauze (Python: `asyncio.sleep(0.2)` na `set_display_mode`).
2. Handshake stap 1 + 2 (met korte delays tussen writes en ACK’s, ~0.2 s default `delay` in `send_frame`).
3. **`CMD_EDIT_END`**: `05 00 04 01 00`
4. **Korte pauze** ~50 ms (`asyncio.sleep(0.05)` na edit end).
5. **Frame-packet** (zie [BLE-PROTOCOL.md](BLE-PROTOCOL.md)) via **write with response** (Python: `write_gatt_char(..., response=True)`).
6. Wacht op notify `05 00 02 00 03` (timeout in code 5 s voor handshake-ACK’s; frame-ACK idem patroon).

### Frame-packet (PNG) — velden

| Offset | Lengte | Inhoud |
|--------|--------|--------|
| 0–1 | 2 | Totaallengte inclusief header (LE) = `len(png) + 15` |
| 2–3 | 2 | `02 00` = image/stream |
| 4 | 1 | `00` = eerste/ enkel; `02` = vervolg |
| 5–8 | 4 | Payloadlengte = `len(png)` (LE) |
| 9–12 | 4 | CRC32 over payload (LE) |
| 13 | 1 | `00` = statisch PNG |
| 14 | 1 | `65` (kanaal) |
| 15+ | N | Ruwe PNG-bytes |

CRC32: **IEEE** polynomial (zlib), 4 bytes LE — zelfde als `binascii.crc32` in Python.

### GIF — chunk-ACK’s

| Richting | Bytes | Betekenis |
|----------|-------|-----------|
| Notify | `05 00 03 00 01` | Chunk ontvangen (volgende chunk mag) |
| Notify | `05 00 03 00 03` | Alle GIF-data ontvangen |

### Paneelcommando’s (voorbeelden) en ACK

| Doel | Write FA02 (payload) | Typische notify ACK (prefix) |
|------|----------------------|-----------------------------|
| Helderheid 50% | `05 00 04 80 32` | `05 00 04 80 01` |
| Rotatie 180° | `05 00 06 80 02` | `05 00 06 80 01` |
| Aan | `05 00 07 01 01` | `05 00 07 01 01` |
| Display mode | `07 00 08 80 01 00` + `mode` (1=static, 2/3 animatie) | `05 00 08 80 01` |
| Edit end | `05 00 04 01 00` | `command_ack` op `04 01` in `[2:4]` |

Volledige constanten: `CMD_*` / `ACK_*` in `display_session.py`.

### GIF — chunking (software)

- **Logische chunk** van GIF: max **12288** bytes ruwe GIF per chunk-header (veld `[5:8]` = **totale** GIF-lengte; CRC over **volledige** GIF).
- **BLE-segmentatie**: elk chunk-packet wordt in stukken van **500** bytes naar FA02 geschreven (met `response=False` waar mogelijk), met **~5 ms** tussen segmenten (`asyncio.sleep(0.005)`).
- Na elke logische chunk: wacht tot notify `05 00 03 00 01` (timeout 2 s).
- Na upload: korte wacht **500 ms**, dan display mode **1** (`07 00 08 80 01 00 01`), **300 ms** pauze, dan mode **2** (`07 00 08 80 01 00 02`) voor animatie (zie `send_gif`).

## Timing — samenvatting (seconden)

| Fase | Ongeveer | Locatie in code |
|------|----------|-----------------|
| Na handshake-stap | 0.2 default (configureerbaar) | `delay` in `send_frame` |
| Na edit end | 0.05 | `send_frame` |
| ACK-wacht | 5.0 max | `wait_for_ack` |
| GIF BLE-segment | 0.005 tussen writes | `send_gif` |
| GIF chunk ACK | 2.0 max | `wait_for` op `frame_ack` |
| GIF na laatste chunk | 0.5 | voor display modes |
| GIF display mode 1→2 | 0.3 tussen | `send_gif` |

Pas op iOS deze tijden minimaal aan als **ondergrens**; panels kunnen trager zijn bij volle bus.

## 16×32

Handshake bevat `32 00` in de **32×32**-referentie. **16×32** vereist eigen metingen — zie [16x32-HARDWARE.md](16x32-HARDWARE.md).
