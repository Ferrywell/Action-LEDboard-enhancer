# Projectstatus — Action LEDboard enhancer

**Laatst bijgewerkt:** 2026-04-01  

Dit document is bedoeld om **sessies te hervatten** (mens of AI-agent): wat er recent is gebeurd, wat nog open kan staan, en waar te kijken bij problemen.

## Repository

- **Remote:** `https://github.com/Ferrywell/Action-LEDboard-enhancer`
- **Branch:** `main`
- **Laatste gedocumenteerde commit (status-snapshot):** `cc9e3dd` — *Fix blank panel: remove BLE serial actor; skip adjustPNG when unchanged; opaque adjustPNG*

Voer `git log -5 --oneline` uit voor actuele geschiedenis na deze snapshot.

## Huidige productfocus

- **iOS-app** (`ios/ActionLEDboard/`): BLE naar Action/BK-Light panelen (`LED_BLE_*`), modi kalender / bericht / vluchten, 32×32 PNG naar paneel.
- **Parity:** Python `tools/ble/send_to_panel.py` gebruikt dezelfde vendorlogica als `reference/panel-hopper-github/vendor/bk_light/display_session.py`.

## Opgeloste / gemitigeerde issues (recent)

### Paneel blijft leeg na “Verzonden naar het paneel” (iOS)

**Symptoom:** Connectie OK, app toont succes, maar **geen zichtbaar beeld** op het fysieke paneel.

**Oorzaak-hypotheses (in volgorde van aanpak):**

1. **RGBA-PNG** — `PanelBitmapRenderer.adjustPNG` gebruikte eerder `UIGraphicsImageRendererFormat` met `opaque = false`, wat **RGBA-PNG** kan geven. Sommige firmware decodeert dat als leeg.  
   **Mitigatie in code:**  
   - `adjustPNG`: `format.opaque = true`.  
   - `BKLightBleClient.sendPNG`: als **rotatie 0°** en **helderheid 100%** (`brightness` ≈ 1.0), wordt **geen** `adjustPNG` toegepast — ruwe `pngData` van `renderLines` (opaque pipeline).

2. **Serialisatie-acteur** — Een tussenliggende `BKLightTransferSerial`-actor is **verwijderd**; `sendPNG` loopt weer rechtstreeks om MainActor/timing-problemen te vermijden.

**Bestanden:** `ios/ActionLEDboard/BLE/BKLightBleClient.swift`, `ios/ActionLEDboard/Rendering/PanelBitmapRenderer.swift`.

**Als het nog steeds misgaat (escalatie voor agents):**

- Vergelijk met **Python** op hetzelfde paneel (`generate_test_png` + `send_to_panel.py`).  
- Vang BLE-notifies/logging af (`-v` Python; iOS `lastNotifyHex` / Xcode-console).  
- Controleer of gebruiker **helderheid onder 100%** of **rotatie ≠ 0** forceert — dan loopt het alsnog door `adjustPNG` (nu opaque).  
- Overweeg kleur/contrast alleen **nadat** payload-bytes gelijkwaardig zijn aan Python.

## Open punten (niet afgevinkt)

- **Hardwarebevestiging** na pull/build op fysiek paneel (gebruiker-test).  
- **16×32** — geen productiebytes zonder hardware-capture ([HARDWARE.md](reference/HARDWARE.md)).  
- **GIF vanuit iOS-UI** — optioneel; Python-pad bestaat al.

## Waar agents beginnen bij een bug

| Symptoom | Eerste stappen |
|----------|----------------|
| BLE connect faalt | [IOS-APP.md](reference/IOS-APP.md), permissies, geen simulator voor echte BLE |
| Send “succes” maar paneel leeg | [§ Paneel blijft leeg](#paneel-blijft-leeg-na-verzonden-naar-het-paneel-ios) hierboven; Python-parity |
| ACK/timeouts | `display_session.py` timing vs `BKLightBleClient`; [IOS-BLE-SEQUENCES.md](reference/IOS-BLE-SEQUENCES.md) |
| Protocoltwijfel | Niet raden — test + documentatie + eventueel `tests/test_ble_protocol.py` |

## Documentatie voor agents

- **[AGENTS.md](../AGENTS.md)** — volledige agentrichtlijnen (mappen, regels, commando’s).  
- **[docs/reference/README.md](reference/README.md)** — index van alle referentiedocs.

## Changelog (kort, handmatig)

| Datum | Notitie |
|-------|---------|
| 2026-04-01 | Documentatie: root `README.md`, `AGENTS.md`, dit bestand; PNG/opaque + sendPNG fast path gedocumenteerd. |
| 2026-04-01 (code) | `cc9e3dd` — BLE serial actor weg; sendPNG skip adjustPNG bij default; adjustPNG opaque. |
