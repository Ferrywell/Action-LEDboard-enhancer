# Projectstatus — Action-LEDboard-enhancer

*Laatste update: 2026-04-01 — Fase A afgerond; geen betaald Apple Developer-account (geen TestFlight).*

**Roadmap (planner):** [ROADMAP.md](ROADMAP.md) · **Opdrachten:** [assignments/](assignments/README.md)

## Lead / product

- **Fase A:** afgerond — Ferry: hardwaretest geslaagd (connect + bericht naar paneel).
- **Distributie:** installatie via **Xcode → eigen iPhone** met gratis Apple ID (Personal Team); **geen** TestFlight/App Store tot eventueel later betaald account.
- **Nu:** **Fase C + D** (GIF op iOS + UX) volgens [ROADMAP.md](ROADMAP.md); Fase B (releasehygiëne zonder TestFlight) is optioneel/licht.

## Samenvatting ronde 2 (archief)

| Agent | Levering |
|--------|-----------|
| **1** | IOS-APP TestFlight §1–2 (checklist, privacy); **18 s GATT-timeout** als `fa02`/`fa03` uitblijven na connect. |
| **2** | `tools/ble/README.md` — **Parity met iPhone** + QA-matrix; pytest 15/15. |
| **3** | **Amber `#ff9900`** als default tekst in `PanelBitmapRenderer`; DISPLAY-DESIGN bijgewerkt. |
| **4** | **`docs/HARDWARE-TEST-SCRIPT.md`** + link in `QA-RELEASE.md`; pytest 15/15. |

## Agent 1 — iOS

- Zie [assignments/agent-1-ios.md](assignments/agent-1-ios.md).

## Agent 2 — BLE-protocol

- Zie [assignments/agent-2-ble-protocol.md](assignments/agent-2-ble-protocol.md).

## Agent 3 — Micro-display UX

- Zie [assignments/agent-3-micro-display-ux.md](assignments/agent-3-micro-display-ux.md).

## Agent 4 — QA

- Zie [assignments/agent-4-qa-release.md](assignments/agent-4-qa-release.md).

---

## Na jouw hardwaretest (vul in)

- Datum test: **2026-04-01** (bevestigd door Ferry)
- Paneel + iPhone: **werkt** — scan, connect, tekst naar paneel OK
- Python parity (`send_to_panel`) getest: **n.v.t.** / later
- Opmerkingen: **geen $99 Apple Developer Program** — geen TestFlight; builds via Xcode naar eigen device.

---

## Volgende stappen (planner)

1. **Fase C:** GIF naar paneel vanaf iOS (Swift + protocolreferentie).
2. **Fase D:** UX op paneel (o.a. helderheid in app — kan al deels gedaan zijn).
3. **Fase B:** alleen als iemand ooit betaald account neemt: TestFlight; anders overslaan.
