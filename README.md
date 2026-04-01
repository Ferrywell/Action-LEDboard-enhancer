# Action LEDboard enhancer

iOS-app (SwiftUI) en PC-hulpmiddelen om **BK-Light / Action LED** pixelpanelen (`LED_BLE_*`) aan te sturen via **Bluetooth Low Energy**. Protocol en frame-opbouw zijn uitgelijnd met de vendorreferentie `reference/panel-hopper-github/vendor/bk_light/display_session.py`.

## Snel starten

| Doel | Waar |
|------|------|
| **iOS bouwen** | Open `ios/ActionLEDboard.xcodeproj` in Xcode (Mac, fysiek iPhone voor echte BLE). Zie [docs/reference/IOS-APP.md](docs/reference/IOS-APP.md). |
| **Python naar paneel** | `tools/ble/` — `pip install -r requirements.txt`, `send_to_panel.py`. Zie [tools/ble/README.md](tools/ble/README.md). |
| **Protocolnaslag** | [docs/reference/BLE-PROTOCOL.md](docs/reference/BLE-PROTOCOL.md) en vendor `display_session.py`. |

## Documentatie

- **[docs/reference/README.md](docs/reference/README.md)** — index van alle referentiedocumenten (hardware, BLE-bytes, iOS, QA).
- **[AGENTS.md](AGENTS.md)** — bedoeld voor **AI-agents en hervatten** (Claude Code, Cursor): mappen, regels, tests, bekende issues.
- **[docs/PROJECT-STATUS.md](docs/PROJECT-STATUS.md)** — actuele projectstaat, recente commits, open punten.

## Repository

- **Remote:** `https://github.com/Ferrywell/Action-LEDboard-enhancer` (branch `main`).
- Lokale planning in **`management/`** wordt niet gecommit (`.gitignore`); alleen voor eigen gebruik.

## Licentie / bronnen

Zie [docs/reference/SOURCES.md](docs/reference/SOURCES.md) en [reference/README.md](reference/README.md) voor de panel-hopper-kloon en credits.
