# Roadmap — Action-LEDboard-enhancer (lead / planner)

*Planner: lead-AI + Ferry. Dit bestand is de bron van waarheid voor **volgorde** en **scope**; details staan in code/docs.*

**Workflow:** zie [assignments/README.md](assignments/README.md). Per fase: juiste agent-chat openen → prompt uit [assignments/PROMPTS.md](assignments/PROMPTS.md) → rapport in `agent-*.md` + korte update in [STATUS.md](STATUS.md).

---

## Huidige fase (samenvatting)

| Fase | Naam | Status |
|------|------|--------|
| **A** | Hardwarevalidatie afronden | **Actief** — script doorlopen + STATUS invullen |
| **B** | TestFlight & releasehygiëne | Start na A |
| **C** | GIF versturen op iOS | Start na B (protocol: `display_session.py` / chunking) |
| **D** | Micro-UX op het paneel | Start na B of parallel aan C (klein) |
| **E** | Python ↔ iOS parity hardenen | Doorlopend waar relevant |
| **F** | 16×32 / andere hardware | **Geblokkeerd** tot BLE-capture of officiële specs |

---

## Fase A — Hardwarevalidatie (kort, verplicht voor “ronde 3 klaar”)

**Doel:** Zelfde feiten in `STATUS.md` als op het werkblad.

1. Loop [docs/HARDWARE-TEST-SCRIPT.md](../docs/HARDWARE-TEST-SCRIPT.md) (15–20 min).
2. Vul in [STATUS.md](STATUS.md) het blok *Na jouw hardwaretest* (datum, device, gelukt/niet, Python parity ja/nee).
3. Optioneel: zelfde test-PNG via PC (`tools/ble/generate_test_png.py` + `send_to_panel.py`) voor visuele parity — zie script § B.

**Agents:** geen code-opdracht; **Agent 4** mag tussentijds typos in test-script melden.

---

## Fase B — TestFlight & release

**Doel:** Reproduerbare build en interne testronde.

| Agent | Opdracht |
|-------|----------|
| **1** | [IOS-APP.md § Nog te doen voor TestFlight](../docs/reference/IOS-APP.md): Info.plist, capabilities, Archive/Distribute-stappen documenteren waar nog gaten zijn; ontbrekende checklistitems in code/docs afvinken. |
| **4** | [QA-RELEASE.md](../docs/QA-RELEASE.md): smoke-checklist (C/R/S/B), release notes-template, link naar HARDWARE-TEST-SCRIPT. |

**Klaar als:** checklist TestFlight + QA rooktests zijn afgevinkt (of expliciet uitgesteld met reden in STATUS).

---

## Fase C — GIF op iOS

**Doel:** Zelfde logica als Python `BleDisplaySession.send_gif` / chunking — **geen** willekeurige protocolbyte-wijzigingen; alleen Swift-implementatie + UI.

| Agent | Opdracht |
|-------|----------|
| **2** | Referentie: `reference/.../display_session.py` (`send_gif`, ACK’s `05 00 03 00`). Tests/pytest groen houden; documenteer afhankelijkheden voor Swift. |
| **1** | GIF kiezen (Photos/Files), naar panel sturen, foutafhandeling; hergebruik `BKLightProtocol` waar mogelijk. |

**Klaar als:** korte GIF op 32×32-paneel speelt (of duidelijke “niet ondersteund”-scope in STATUS).

---

## Fase D — Micro-UX (paneel)

**Doel:** Bediening zonder Mac.

| Agent | Opdracht |
|-------|----------|
| **3** | Heldere **helderheid** in de app (`setBrightness` bestaat al in `BKLightBleClient`) — slider of stappen; korte copy. Optioneel: rotatie als die in UI ontbreekt. |

**Klaar als:** gebruiker kan helderheid aanpassen zonder Xcode.

---

## Fase E — Parity Python ↔ iOS (doorlopend)

- Bij elke protocolwijziging: `tests/test_ble_protocol.py` + iOS `BKLightProtocol.swift` synchroon houden.
- `tools/ble/README.md` *Parity met iPhone* blijft de handleiding voor handmatige vergelijking.

---

## Fase F — 16×32 / andere SKU’s

- **Niet starten** tot handshake/frame-bytes gemeten zijn ([HARDWARE.md](../docs/reference/HARDWARE.md), [16x32-HARDWARE.md](../docs/reference/16x32-HARDWARE.md)).
- Geen geraden `32 00`-wijzigingen in productie-builds.

---

## Volgorde (én-één-lijn)

```
A (validatie) → B (TestFlight/QA) → C (GIF) ─┬→ D (UX)
                                             └→ E (doorlopend)
F = aparte track, alleen na metingen
```

---

## Herinnering voor Ferry

- Na elke merge die je op de Mac nodig hebt: `git pull` op `main`.
- Agents starten pas als de **Huidige opdracht (lead)** in hun `agent-*.md` overeenkomt met de fase hierboven (lead past dat aan bij fase-switch).
