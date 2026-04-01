# Referentiedocumentatie (Action LED / BK-Light)

Deze map bundelt **feiten uit code, GitHub en eerdere projecten** voor het nieuwe **Action-LEDboard-enhancer** project. Gebruik dit als startpunt voor iOS-app, PC-tools of protocoluitbreidingen.

## Documenten

| Bestand | Inhoud |
|---------|--------|
| [SOURCES.md](SOURCES.md) | Repositories, lokale backup-locatie, credits, hoe de referentie-repo bij te werken |
| [HARDWARE.md](HARDWARE.md) | Action-producten (32×32 vs 16×32), BLE-naam `LED_BLE_*`, ondersteuningsstatus |
| [BLE-PROTOCOL.md](BLE-PROTOCOL.md) | GATT-UUID’s, handshake, PNG-frames, GIF-chunks, ACK’s, paneelcommando’s |
| [DISPLAY-DESIGN.md](DISPLAY-DESIGN.md) | Informatiedesign 32×32: dot-matrix, leesbaarheid, PNG vs GIF per feature, pipeline |
| [IOS-APP.md](IOS-APP.md) | iOS SwiftUI-app: paden, Xcode, scan/connect, chunking (500 B write vs 12 KB GIF), 16×32-waarschuwing |
| [IOS-BLE-SEQUENCES.md](IOS-BLE-SEQUENCES.md) | Exacte bytes en timing voor iOS (CoreBluetooth), CRC/frame-layout |
| [PLATFORM-BLE.md](PLATFORM-BLE.md) | Verschillen Windows / Linux / macOS / iOS (MTU, writes, rechten) |
| [16x32-HARDWARE.md](16x32-HARDWARE.md) | 16×32: geen geraden constanten — alleen na hardware-capture |
| [IPixel-RESEARCH.md](IPixel-RESEARCH.md) | iPixel Color-app: APK (`BaseSend.java`, `SendCore.java`), BLE-capture, chunkgrootte |
| [QA-RELEASE.md](../QA-RELEASE.md) | Testscenario’s, Python vs iOS, hardware/BT-issues, TestFlight & pre-merge smoke, escalaties |

## Lokale code-kopie (GitHub)

De repository **[Ferrywell/panel-hopper](https://github.com/Ferrywell/panel-hopper)** staat gekloond onder:

`reference/panel-hopper-github/`

Belangrijkste paden daar:

- `vendor/bk_light/display_session.py` — BLE-sessie, handshake, GIF, iPixel-commando’s
- `src/panel_hopper/` — panel manager, graphics (32×32)
- `web/server.py` — FastAPI + endpoints
- `README.md` — architectuur, API-tabel, GIF-protocol

Wijzigingen in die clone: alleen maken als je bewust forked; voor dit project liever **eigen app-code** naast deze referentie houden.

## Coördinatie (agents)

- **Opdrachten (per agent):** [management/assignments/](../../management/assignments/README.md)
- **Statusoverzicht:** [management/STATUS.md](../../management/STATUS.md)
- **Werkwijze lead ↔ agents:** [management/LEAD-CYCLE.md](../../management/LEAD-CYCLE.md)
