# Roadmap — Action-LEDboard-enhancer (lead / planner)

*Planner: lead-AI + Ferry. Details in code/docs; dit bestand = volgorde en scope.*

**Workflow:** [assignments/README.md](assignments/README.md) · prompts: [assignments/PROMPTS.md](assignments/PROMPTS.md)

**Distributie (projectkeuze):** geen verplicht **betaald** Apple Developer Program. Standaard: **Xcode → eigen iPhone** met **gratis Apple ID** (Personal Team, ~7 dagen signing). **TestFlight / App Store** alleen als later een betaald account wordt genomen.

---

## Huidige fase (samenvatting)

| Fase | Naam | Status |
|------|------|--------|
| **A** | Hardwarevalidatie | **Afgerond** (Ferry: werkt op echt paneel) |
| **B** | Releasehygiëne | **Optioneel** — licht; **geen** TestFlight zonder $99-account |
| **C** | GIF versturen op iOS | **Actief** volgende grote feature |
| **D** | Micro-UX (paneel) | **Actief** (o.a. helderheid in UI) |
| **E** | Python ↔ iOS parity | Doorlopend |
| **F** | 16×32 | **Geblokkeerd** tot metingen |

---

## Fase A — Hardwarevalidatie

**Afgerond** — zie [STATUS.md](STATUS.md) blok *Na jouw hardwaretest*.

---

## Fase B — Releasehygiëne (optioneel, geen TestFlight)

**Doel:** Alleen wat zinvol is zonder betaald account.

| Agent | Opdracht |
|-------|----------|
| **1** | Info.plist, BLE-capabilities, icon — consistent met build op device; **geen** Archive→TestFlight-stappen verplicht. |
| **4** | Rookscenario’s (handmatig op device), geen App Store Connect-checklist. |

**Overslaan** als alleen Ferry lokaal bouwt: dat is OK.

---

## Fase C — GIF op iOS

**Doel:** Zelfde logica als Python `BleDisplaySession.send_gif` / chunking — **geen** willekeurige protocolbyte-wijzigingen.

| Agent | Opdracht |
|-------|----------|
| **2** | Referentie: `display_session.py` (`send_gif`, ACK’s). Pytest groen. |
| **1** | GIF kiezen, naar panel sturen, foutafhandeling. |

---

## Fase D — Micro-UX (paneel)

| Agent | Opdracht |
|-------|----------|
| **3** | Helderheid + evt. rotatie in UI; `setBrightness` / `sendPNG` parameters. |

---

## Fase E — Parity Python ↔ iOS (doorlopend)

- Tests + `BKLightProtocol.swift` synchroon houden bij protocolwijzigingen.

---

## Fase F — 16×32

- Niet starten tot handshake/frame vastliggen.

---

## Volgorde

```
A ✓ → (B optioneel) → C (GIF) + D (UX) parallel mogelijk → E doorlopend
F = apart, geblokkeerd
```

---

## Ferry

- `git pull` op `main` na wijzigingen.
- Geen TestFlight nodig voor dit project tenzij je zelf een betaald account wilt.
