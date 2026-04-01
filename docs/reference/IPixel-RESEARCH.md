# iPixel Color — onderzoeksmethoden en verwijzingen

De officiële app **iPixel Color** (fabrikant / BK-Light-ecosysteem) wordt in Panel Hopper op twee manieren benut:

1. **BLE capture analysis** — verkeer sniffen terwijl de app naar het paneel schrijft (grondwaar voor timing, ACK’s, chunking).
2. **Android APK decompilatie** — klassen en methodenamen als **hint** voor commandobytes en volgorde.

Dit document **vervangt geen licentie-advies**: reverse engineering voor interoperabiliteit verschilt per rechtsgebied; houd fabrikantvoorwaarden in de gaten.

## Wat uit de APK naar voren komt (Panel Hopper commentaar)

In `vendor/bk_light/display_session.py` worden onder andere genoemd:

| Bron (Java) | Gebruik in Python |
|-------------|-------------------|
| `BaseSend.java` | o.a. `sendLedOnOff`, `deleteAllData` → bijbehorende `CMD_*` bytes |
| `SendCore.java` | `getDataType()`, payload-/framelogica → `DATA_TYPE_IMAGE`, `DATA_TYPE_GIF`, `build_frame` |
| Chunkgrootte | `CHUNK_SIZE = 12288` — “from iPixel APK” |

Server/manager verwijzen op sommige plekken naar dezelfde commando’s (bijv. on/off, delete all).

## Wat uit BLE-capture komt

- **GIF-protocol**: datatype `0x03 0x00`, chunk-ACK’s `05 00 03 00 01` / `05 00 03 00 03`, volgorde display modes na transfer.
- **Stilstaand beeld**: volgorde handshake → `CMD_EDIT_END` → frame; optioneel display mode static om animatie te stoppen.

Panel Hopper README: *“The GIF animation protocol was reverse-engineered from the iPixel Color app through BLE capture analysis.”*

## iPixel-bibliotheek in de webapp

Upstream bevat een **map met honderden GIF’s** (`web/static/ipixel_gifs/`, API `/api/ipixel-gifs`). In een **shallow clone** kunnen die assets ontbreken als ze niet in git zitten of via LFS gaan — dan lokaal uit volledige repo of release halen.

## Suggestie voor vervolg (16×32 / langwerpig)

1. Officiële app op **Android** met **HCI snoop** of nRF Sniffer: vergelijk handshake bytes met 32×32-paneel.
2. Optioneel APK: zoek naar resolutie- of product-id constanten die naar **16×32** wijzen.
3. Wijzigingen **niet gokken** in productie zonder capture op het echte **LED Pixel Scherm**-hardware.
