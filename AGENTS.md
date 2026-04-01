# Richtlijnen voor AI-agents (Claude Code, Cursor, enz.)

Dit bestand helpt bij **hervatten van het werk** en bij het bouwen van **gestuurde agents** die code wijzigen, testen of documenteren. Lees dit vóór grote wijzigingen; volg daarna de diepere referenties per onderwerp.

## 1. Doel van de repository

- **iOS-app** onder `ios/ActionLEDboard/`: SwiftUI, BLE Central naar GATT `fa02` (write) / `fa03` (notify), zelfde semantiek als Python `BleDisplaySession`.
- **Referentiecode** onder `reference/panel-hopper-github/` (vendor clone) — vooral `vendor/bk_light/display_session.py` als **bron van waarheid** voor bytes, timing, ACK’s, `build_frame`.
- **PC-tools** onder `tools/ble/` voor parity-tests zonder iOS-build.

## 2. Leesvolgorde (minimum)

1. [docs/reference/BLE-PROTOCOL.md](docs/reference/BLE-PROTOCOL.md) — GATT, handshake, PNG-frame, chunking.
2. [docs/reference/IOS-APP.md](docs/reference/IOS-APP.md) — waar wat staat, Xcode, simulator-limieten.
3. [docs/PROJECT-STATUS.md](docs/PROJECT-STATUS.md) — huidige staat, bekende bugs, volgende stappen.
4. Bij byte-niveau twijfel: **`reference/panel-hopper-github/vendor/bk_light/display_session.py`** (niet dupliceren; importeer of align Swift).

## 3. Architectuur (kort)

| Onderdeel | Pad |
|-----------|-----|
| BLE-client, scan/connect, chunk writes, ACK-wacht | `ios/ActionLEDboard/BLE/BKLightBleClient.swift` |
| Protobuf-achtige frame/CRC/command constanten | `ios/ActionLEDboard/BLE/BKLightProtocol.swift` |
| 32×32 PNG (tekst, `adjustPNG`) | `ios/ActionLEDboard/Rendering/PanelBitmapRenderer.swift` |
| Hoofd-UI, modi kalender/bericht/vluchten | `ios/ActionLEDboard/ContentView.swift` |
| Agenda / vluchten | `Services/CalendarEventsProvider.swift`, `FlightBoardProvider.swift` |
| Python send + tests | `tools/ble/send_to_panel.py`, `tests/test_ble_protocol.py` |

**Belangrijk:** `BKLightBleClient` is `@MainActor`. CoreBluetooth-callbacks lopen op `DispatchQueue` (`bklight.ble`); houd deadlocks en “send tijdens send” in de gaten.

## 4. Harde regels (niet breken zonder expliciete beslissing)

- **Protocolconstanten** (handshake, `CMD_*`, frame-layout, CRC) niet “verbeteren” op gevoel — alleen na vergelijking met `display_session.py` en update van [docs/reference/BLE-PROTOCOL.md](docs/reference/BLE-PROTOCOL.md) / tests.
- **16×32-hardware:** geen geraden handshake-bytes; zie [docs/reference/HARDWARE.md](docs/reference/HARDWARE.md) en [16x32-HARDWARE.md](docs/reference/16x32-HARDWARE.md).
- **PNG naar paneel:** firmware kan **RGBA-PNG** soms als leeg tonen. Renderer gebruikt opaque PNG waar mogelijk; `sendPNG` slaat `adjustPNG` over bij rotatie 0° en helderheid 100% (zie `BKLightBleClient.sendPNG`). Zie [docs/PROJECT-STATUS.md](docs/PROJECT-STATUS.md).

## 5. Commando’s (ontwikkelaar / CI-achtig)

**Python (repo-root, Windows PowerShell voorbeeld):**

```powershell
cd tools/ble
pip install -r requirements.txt
```

```powershell
cd ..\..
pip install -r requirements-dev.txt
pytest tests/test_ble_protocol.py -v
```

**iOS:** alleen op Mac met Xcode — `ios/ActionLEDboard.xcodeproj`, zie IOS-APP.md.

## 6. Parity-debugflow (aanbevolen bij “iOS stuurt, paneel reageert niet”)

1. Zelfde paneel, **één** central tegelijk.
2. Eerst **Python:** `tools/ble/generate_test_png.py` + `send_to_panel.py` — bevestigt hardware + protocol vanaf PC.
3. Daarna iOS met vergelijkbare inhoud — zie [tools/ble/README.md](tools/ble/README.md) en [docs/QA-RELEASE.md](docs/QA-RELEASE.md).

## 7. Wat niet in Git staat

- **`management/`** — lokaal; `.gitignore`. Bestaat niet op verse clone.

## 8. Suggesties voor agent-taken (veilig scoped)

- **Docs:** alleen bij expliciete user-vraag uitbreiden; anders code + `docs/PROJECT-STATUS.md` / `AGENTS.md` bijwerken.
- **BLE:** kleine, geteste wijzigingen; pytest draaien; geen grote refactors zonder failing test of hardware-issue.
- **UI:** `ContentView` en design tokens consistent houden met bestaande SwiftUI-patronen in de app.

## 9. Gerelateerde documenten

| Document | Inhoud |
|----------|--------|
| [docs/reference/README.md](docs/reference/README.md) | Masterindex referentie |
| [docs/QA-RELEASE.md](docs/QA-RELEASE.md) | Testmatrix, TestFlight, escalatie |
| [docs/reference/IOS-BLE-SEQUENCES.md](docs/reference/IOS-BLE-SEQUENCES.md) | Exacte bytes/timing iOS |
| [docs/reference/PLATFORM-BLE.md](docs/reference/PLATFORM-BLE.md) | iOS vs desktop BLE |

Laatste aanbeveling: na substantiële wijzigingen **`docs/PROJECT-STATUS.md`** bijwerken (datum, commit, korte notitie) zodat de volgende sessie direct context heeft.
