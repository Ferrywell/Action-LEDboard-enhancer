# QA & release: Action-LEDboard-enhancer

Dit document beschrijft testscenario’s per feature, vergelijking **Python-send (panel-hopper)** versus **iOS-send** naar hetzelfde fysieke paneel, bekende hardware/BT-risico’s, en checklists voor **TestFlight** en **smoke tests vóór merge**. Escalatiepaden staan onderaan.

**Referentie:** [BLE-PROTOCOL.md](reference/BLE-PROTOCOL.md), [HARDWARE.md](reference/HARDWARE.md), iOS `BKLightProtocol.swift` (uitlijning met `display_session.py`).

### Implementatiestatus (repo)

- **`docs/PROJECT-STATUS.md`**: korte **hervat-snapshot** (datum, commits, bekende bugs zoals leeg paneel na send, volgende stappen) — nuttig voor AI-agents en nieuwe sessies.
- **`docs/QA-RELEASE.md`** (dit bestand): rollen, testmatrix Python vs iOS, scenario-ID’s **C / R / B / S / G / M**, hardware/BT, smoke- en TestFlight-checklists, protocolonzekerheden.
- **iOS:** `ios/ActionLEDboard/` bevat o.a. `ContentView.swift` (BLE-scan/connect, modi kalender / bericht / vluchten, send), `BKLightBleClient` + `BKLightProtocol`, providers en `PanelBitmapRenderer`. De scenario’s hieronder zijn **uitvoerbaar** zodra je een fysiek paneel en TestFlight/debug-build hebt; verdere UI-polish (foutteksten, GIF-kiezer, enz.) kan nog open staan — escaleer UX naar micro-display UX.
- **Python:** volledige send en GIF blijven te valideren via `reference/panel-hopper-github` en `tools/ble/` voor pariteit met iOS.

---

## Rollen & escalatie

| Type issue | Eigenaar / doorverwijzing |
|------------|---------------------------|
| **Protocolonzekerheden** (handshake-bytes, 16×32, ACK-afwijkingen, chunkgrootte, firmwareverschillen) | **BLE-protocol engineer** — wijzig `display_session.py` / `BKLightProtocol.swift` alleen na afgestemde beslissing; zie ook sectie [Protocolonzekerheden](#protocolonzekerheden-escalatie-naar-ble-protocol-engineer). |
| **UX** (scan/connect flows, foutmeldingen, helderheidsslider, GIF-kiezer, modi-labels, toegankelijkheid) | **Micro-display UX** — visuele en interactieve kwaliteit los van byte-niveau. |
| **Release / build** | QA & release engineer (dit document). |

---

## Testmatrix: Python vs iOS (zelfde paneel)

Gebruik **één fysiek 32×32** Action Pixelbord (`LED_BLE_*`). Voer dezelfde actie eerst via **panel-hopper** (CLI of `web/server.py`), daarna via **iOS TestFlight-build** (of debug). Noteer: zichtbaar resultaat, latency, fouten in logs.

| Gebied | Python (panel-hopper) | iOS-app | Verwachting bij pariteit |
|--------|------------------------|---------|---------------------------|
| Verbinding | `scan` + connect via Bleak/manager | CoreBluetooth scan + connect | Zelfde paneel bereikbaar; vergelijkbare connect-tijd (iOS kan iets andere scan-interval hebben). |
| Reconnect | Verbinding verbreken (paneel uit/aan, afstand) + opnieuw verbinden | Idem | Beide herstellen handshake/sessie; geen “hangende” oude status zonder duidelijke fout. |
| Helderheid | API/CLI → `CMD_BRIGHTNESS` 0–100 | Zelfde commando in `BKLightProtocol` | Zelfde helderheid visueel; ACK-gedrag vergelijkbaar. |
| Statisch beeld | PNG naar 32×32, handshake + `CMD_EDIT_END` + `build_frame` | Idem in Swift | Zelfde beeld op paneel; kleur/resampling kan minimaal verschillen door encoder. |
| GIF | Chunks 12 KB, sub-writes 500 B, ACK `05 00 03 00 …` | `gifChunkPayloadMax`, `bleWriteChunkSize` gelijk aan Python | Zelfde animatie; bij afwijking: logs + BLE-capture, escalate protocol. |
| Modi | `set_display_mode` / display mode bytes na GIF | `displayModeCommand` | Zelfde gedrag (static / animate / prepare — conform app-UI). |

**Note:** 16×32 (Action “Pixel Scherm”) is **niet gegarandeerd** in upstream; scenario’s daarop zijn **exploratief** tot de BLE-protocol engineer handshake/frame-parameters vastlegt ([HARDWARE.md](reference/HARDWARE.md)).

---

## Testscenario’s per feature

### 1. BLE-connect

| ID | Scenario | Stappen | Succescriteria |
|----|----------|---------|----------------|
| C1 | Eerste koppeling | Paneel aan, binnen ~5 m. Start scan, selecteer `LED_BLE_*`, connect. | Verbinding “connected”; GATT write/notify beschikbaar; geen crash. |
| C2 | Paneel niet in range | Scan zonder paneel of met uitgeschakelde Bluetooth. | Duidelijke fout of lege lijst; geen hang; herstel na BT aan. |
| C3 | Tweede apparaat | (Optioneel) Tweede central mag paneel niet gelijktijdig “bezitten” — verwacht één actieve sessie; documenteer firmware-gedrag. | Voorspelbaar gedrag, geen corrupte state in app. |

**Python vs iOS:** zelfde paneel-MAC; vergelijk tijd tot “ready to send” en of optionele web-UI dezelfde status toont als iOS.

---

### 2. Reconnect

| ID | Scenario | Stappen | Succescriteria |
|----|----------|---------|----------------|
| R1 | Soft reconnect | Verbind, verbreek BLE (app disconnect of paneel kort stroomloos), connect opnieuw. | Nieuwe handshake slaagt; volgende send werkt. |
| R2 | Paneel uit/aan | Verbonden, paneel uit, weer aan, opnieuw scannen en verbinden. | Geen vereiste handmatige app-kill; foutafhandeling acceptabel als duidelijk. |
| R3 | Lange idle | Verbonden laten staan zonder traffic (b.v. 10–30 min), daarna helderheid of beeld sturen. | Sessie nog geldig of duidelijke “opnieuw verbinden”. |

**Escalatie:** als reconnect alleen op één platform faalt → logs + mogelijk protocol-timer (BLE-protocol engineer).

---

### 3. Helderheid

| ID | Scenario | Stappen | Succescriteria |
|----|----------|---------|----------------|
| B1 | Min / max | Zet op 0 (of minimum) en 100. | Paneel reageert; geen crash bij grenzen. |
| B2 | Middenwaarden | 25, 50, 75 na elkaar. | Monotone verandering (subjectiveel OK bij LED-stappen). |
| B3 | Na reconnect | Helderheid wijzigen, reconnect, opnieuw meten of UI state klopt. | Consistent gedrag of gedocumenteerde firmware-reset naar default. |

**Python vs iOS:** zelfde waarden achter elkaar op hetzelfde paneel; visueel gelijk binnen LED-stappen.

---

### 4. Statisch beeld

| ID | Scenario | Stappen | Succescriteria |
|----|----------|---------|----------------|
| S1 | Standaard PNG | 32×32 of door app geschaald; upload/send. | Beeld zichtbaar, geen half frame. |
| S2 | Transparantie / rand | PNG met alpha (als ondersteund). | Gedrag gedefinieerd: of platte kleur, of documenteer afwijking. |
| S3 | Groot bronbestand | >32×32 pixels. | Downscale zonder crash; geen onacceptabele wachttijd. |

**Python vs iOS:** vergelijk twee vaste test-PNG’s (b.v. effen rood + raster); check kleurverschil door gamma/encoder.

---

### 5. GIF

| ID | Scenario | Stappen | Succescriteria |
|----|----------|---------|----------------|
| G1 | Klein GIF | < 12 KB totaal. | Afspeelt; ACK-loop zonder timeout. |
| G2 | Groot GIF | Meerdere 12 KB-chunks. | Alle chunks ACK’t; animatie start. |
| G3 | Langzame animatie | Weinig frames, lage FPS. | Vloeiend binnen paneel-limieten. |
| G4 | Foutpad | Corrupte of lege file (test). | Duidelijke fout, geen crash. |

**Python vs iOS:** zelfde bestand vanaf disk; bij afwijking: chunk-telling en notify-handler vergelijken (protocol).

---

### 6. Modi (display mode / static vs animatie)

| ID | Scenario | Stappen | Succescriteria |
|----|----------|---------|----------------|
| M1 | Static na GIF | Schakel naar static (mode conform app — zie `CMD_DISPLAY_MODE` / README). | Animatie stopt; laatste frame of leeg conform ontwerp. |
| M2 | Prepare / animate | Na GIF-upload: prepare → animate volgens app-flow. | Overeenkomst met verwachte firmware-sequentie. |
| M3 | Wissen / reset | “Delete all” of app-equivalent. | Paneel wist content; geen zombie-frames na nieuwe upload. |

**Escalatie:** onduidelijk welke mode-byte welk factory-gedrag triggert → BLE-protocol engineer + officiële app-capture ([IPixel-RESEARCH.md](reference/IPixel-RESEARCH.md)).

---

## Bekende hardware- en Bluetooth-issues

Samenvatting voor testers en release notes (uit [HARDWARE.md](reference/HARDWARE.md) en panel-hopper README).

| Issue | Impact | Mitigatie |
|-------|--------|-----------|
| **Windows: admin-rechten** | BLE-scan/connect kan falen zonder elevated terminal. | Testprocedure: PowerShell/CMD **als Administrator** bij Python-tools; vermeld in release notes voor PC-gebruikers. |
| **USB BLE-dongels vs ingebouwd** | Niet alle chipsets even stabiel met lange GATT-writes. | Bij problemen: geteste dongels (CSR8510, RTL8761B, Intel AX200/AX210) uit README; andere adapters als “best effort”. |
| **BLE 4.0+ central** | Oudere adapters zonder BLE werken niet. | Hardware-eis in FAQ. |
| **16×32 paneel** | Handshake `32 00` mogelijk incorrect; gedrag ongedefinieerd. | Geen release-claim “ondersteund” tot protocol vastgelegd; escalatie BLE-protocol engineer. |
| **Concurrente verbindingen** | Twee centrals tegelijk op één paneel kan firmware niet ondersteunen. | Test niet gelijktijdig twee senders naar hetzelfde paneel voor productie-validatie. |

---

## Smoke tests vóór merge (kort)

Uitvoeren op **minstens één** iOS-testdevice + waar relevant **één** Windows-setup met panel-hopper ter referentie.

- [ ] App start zonder crash; permissies (Bluetooth) correct gevraagd.
- [ ] Scan toont paneel (`LED_BLE_*`) wanneer aanwezig.
- [ ] Connect + disconnect werkt (happy path).
- [ ] Eén statisch testbeeld naar paneel.
- [ ] Helderheid één keer wijzigen.
- [ ] (Indien in scope) één referentie-GIF.
- [ ] Geen regressie in build (geen warnings die als fout zijn ingesteld).

**Duur:** typisch 15–30 minuten per platform.

---

## TestFlight-checklist (release-kandidaat)

### Build & metadata

- [ ] Versienummer / build-nummer verhoogd; **TestFlight**-build geüpload.
- [ ] **Release notes** (NL/EN naar doelgroep): bekende BT-limitaties (Windows admin voor Python-tools; dongels).
- [ ] **Privacy / permissies:** Bluetooth-gebruikstekst in Info.plist accuraat en review-vriendelijk.

### Functioneel (minimaal)

- [ ] Alle **smoke tests** hierboven op een fysiek 32×32 paneel.
- [ ] **Reconnect** (R1) minstens één keer geslaagd.
- [ ] Geen **blocker**-crashes in kernflow (scan → connect → send).

### Niet-blocker maar tracken

- [ ] UX-kleine issues gelogd voor **micro-display UX**.
- [ ] Openstaande protocolvragen gelogd voor **BLE-protocol engineer**.

### Na externe test

- [ ] Feedback uit TestFlight verwerkt of geclassificeerd (bug / enhancement / wontfix).
- [ ] Go voor productie-release of nieuwe RC.

---

## Protocolonzekerheden (escalatie naar BLE-protocol engineer)

Deze punten **niet** alleen in QA sluiten; eigenaar is protocol/engineering:

1. **16×32:** Andere handshake/frameparameters dan `32 00` — meten of BLE-capture met officiële app ([HARDWARE.md](reference/HARDWARE.md)).
2. **GIF:** Exacte mode-sequentie na laatste chunk (`07 00 08 80 01 00 01` vs `…02`) — afstemmen op firmware en iPixel-referentie.
3. **ACK-varianten:** Nieuwe firmware die afwijkende notify-patterns stuurt → uitbreiden `AckWatcher` / `isCommandAck` in overleg.
4. **Chunkgrootte / MTU:** Afwijking van 12288 / 500 B op bepaalde iOS-versies of Android-ref — valideren op hardware.

---

## UX-issues (escalatie naar micro-display UX)

Voorbeelden van wat hierheen gaat (geen byte-wijzigingen):

- Onduidelijke fout bij “paneel niet gevonden” vs “Bluetooth uit”.
- Slider-stappen voor helderheid vs paneel-stappen.
- GIF-kiezer: lange uploads zonder voortgang.
- Labels voor “modi” die niet overeenkomen met gebruikersverwachting.

---

### Laatste automatische check

- **2026-04-01:** `pytest tests/test_ble_protocol.py -v` — **15 passed** in ~0,05s (Windows, Python 3.13). *Volledige suite:* alleen `test_ble_protocol.py` gedraaid zoals opdracht; geen regressie in protocol-/ACK-tests.

### Handmatig op hardware (nog niet uitgevoerd)

De volgende punten zijn **niet** door geautomatiseerde tests afgedekt en vereisen een **echt BK-Light-paneel** en **iPhone** (TestFlight of debug) naast eventueel Python/panel-hopper ter vergelijking. Ze worden hier **niet** als geslaagd gerapporteerd totdat ze op hardware zijn uitgevoerd.

- Scan en eerste **BLE-connect** naar `LED_BLE_*`, inclusief permissies en foutpaden (paneel uit, BT uit, buiten bereik).
- **Reconnect** na stroomonderbreking paneel, app naar achtergrond, of langere idle — handshake en send daarna.
- **Helderheid en rotatie** zichtbaar op de matrix; grenswaarden en gedrag na reconnect.
- **Statisch beeld (PNG)** — kleur, scherpte, downscale van grotere bron; vergelijking met Python-send op hetzelfde paneel.
- **GIF** — chunking, animatie, grote bestanden, timeouts; pariteit iOS vs Python.
- **Display-modi** (static / animate / wissen) en app-specifieke flows (kalender, bericht, vluchten) op het fysieke display.
- **Latency en stabiliteit** bij herhaald versturen, concurrente gebruikersscenario’s (één central per paneel).
- **16×32-paneel** (indien beschikbaar) — exploratief; geen claim op succes tot protocol vastligt.

---

**Snelle hardwaretest (Ferry, ~15–20 min):** stapsgewijze handleiding in **[HARDWARE-TEST-SCRIPT.md](HARDWARE-TEST-SCRIPT.md)**.

---

*Documentversie: afgestemd op repository-state; werk `BKLightProtocol.swift` en `docs/reference` bij wanneer het protocol formeel wijzigt.*
