# BLE-platformverschillen (PC ↔ iOS)

De **bytevolgorde en protocol** zijn identiek op alle platforms; verschillen zitten in **stack, rechten en MTU**.

## GATT (zelfde overal)

| Rol | UUID-string (CoreBluetooth / Bleak) |
|-----|-------------------------------------|
| Write | `0000FA02-0000-1000-8000-00805F9B34FB` |
| Notify | `0000FA03-0000-1000-8000-00805F9B34FB` |

iOS: `CBUUID(string:)` is case-insensitive; gebruik lowercase of uppercase consequent binnen de app.

## Windows (Bleak)

- **Beheerdersrechten**: vaak nodig voor stabiele BLE-toegang (zie Panel Hopper README).
- **Write**: `display_session.py` probeert eerst `write_gatt_char(..., response=False)` bij “normale” writes; bij fouten schakelt het over naar **write with response** (`response=True`). iOS moet het equivalent kiezen: `CBCharacteristicWriteWithResponse` als het paneel dat vereist voor grote payloads; anders kan `WithoutResponse` falen of fragmenten anders verwerken.
- **MTU**: `exchange_mtu(512)` wordt geprobeerd; werkelijke ATT-MTU kan lager zijn — **GIF-chunks** worden in software in 500-byte BLE-segmenten gesplitst (zie `send_gif`).

## Linux (Bleak)

- Bluetooth stack (BlueZ) verschilt per distro; zelfde Python-code als Windows, maar **pairing** en **adapter** kunnen extra stappen nodig hebben.

## macOS (Bleak)

- Gebruikelijk stabiel voor BLE central; MTU/fragmentatie vergelijkbaar met Linux.

## iOS (CoreBluetooth)

- **Geen Bleak**: app is **central**, paneel is **peripheral**.
- **Notify**: schrijf `notify` aan op `FA03` vóór je vertrouwt op ACK’s; parse `peripheral:didUpdateValueForCharacteristic:` payloads als ruwe `Data` (byte-identiek aan `AckWatcher` in Python).
- **Writes**: segmenteer grote writes over **MTU − 3 / overhead** (typisch ~240–500 bytes effectief payload per ATT-write, afhankelijk van onderhandelde MTU); align met Python `MTU_SIZE = 500` in `send_gif` voor GIF-chunks.
- **Timing**: gebruik **niet** nul delays tussen opeenvolgende writes voor multi-packet GIF-chunks — Python gebruikt ~5 ms tussen segmenten; zie [IOS-BLE-SEQUENCES.md](IOS-BLE-SEQUENCES.md).
- **Queue**: `CBPeripheral` staat doorgaans niet toe om onbeperkt snel te schrijven; serialiseer writes op dezelfde manier als `await _safe_write` in een loop.

## Samenvatting voor iOS-ontwikkelaar

1. Zelfde hex-bytes als in `display_session.py` en [IOS-BLE-SEQUENCES.md](IOS-BLE-SEQUENCES.md).
2. ACK’s op notify **FA03** zijn byte-exact te vergelijken met `AckWatcher.handler`.
3. Test op **fysiek** paneel: emulators geven geen BLE.
