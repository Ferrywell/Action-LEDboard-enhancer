# Projectstatus — Action-LEDboard-enhancer

*Laatste update: 2026-04-01 — ronde 2 afgerond; wacht op hardwaretest Ferry*

**Opdrachten:** [assignments/](assignments/README.md) · **Prompts:** [assignments/PROMPTS.md](assignments/PROMPTS.md) · **Test:** [docs/HARDWARE-TEST-SCRIPT.md](../docs/HARDWARE-TEST-SCRIPT.md)

## Lead / product

- **Ronde 2 (2026-04-01):** alle vier agents gerapporteerd — zie onder. Pytest BLE-protocol: **15/15** (ook in ronde 2 bevestigd).
- **Nu:** geen nieuwe agent-ronde tot **jij** de hardwaretest hebt gedaan (of expliciet aangeeft dat we zonder paneel verder gaan met iets anders).

## Samenvatting ronde 2

| Agent | Levering |
|--------|-----------|
| **1** | IOS-APP TestFlight §1–2 (checklist, privacy); **18 s GATT-timeout** als `fa02`/`fa03` uitblijven na connect. |
| **2** | `tools/ble/README.md` — **Parity met iPhone** + QA-matrix; pytest 15/15. |
| **3** | **Amber `#ff9900`** als default tekst in `PanelBitmapRenderer`; DISPLAY-DESIGN bijgewerkt. |
| **4** | **`docs/HARDWARE-TEST-SCRIPT.md`** + link in `QA-RELEASE.md`; pytest 15/15. |

## Agent 1 — iOS

- Zie [assignments/agent-1-ios.md](assignments/agent-1-ios.md) (rapport + archief).

## Agent 2 — BLE-protocol

- Zie [assignments/agent-2-ble-protocol.md](assignments/agent-2-ble-protocol.md).

## Agent 3 — Micro-display UX

- Zie [assignments/agent-3-micro-display-ux.md](assignments/agent-3-micro-display-ux.md).

## Agent 4 — QA

- Zie [assignments/agent-4-qa-release.md](assignments/agent-4-qa-release.md).

---

## Blockers / beslissing lead

- **Geen** code-blokkers uit agents.
- **GIF-send op iOS** nog bewust buiten scope (kan na eerste hardware-feedback).

### Na jouw hardwaretest (vul in)

- Datum test:
- Paneel + iPhone: werkt / werkt niet (kort):
- Python parity (`send_to_panel`) getest: ja / nee / n.v.t.
- Opmerkingen voor lead:

---

## Volgende stappen

1. **Ferry:** loop [`docs/HARDWARE-TEST-SCRIPT.md`](../docs/HARDWARE-TEST-SCRIPT.md) (15–20 min).
2. Vul hierboven **Na jouw hardwaretest** in, of stuur de lead een chat met dezelfde info.
3. Daarna: lead zet **ronde 3** (fixes / GIF / TestFlight) in `management/assignments/agent-*.md` — agents pauzeren tot dat gebeurt.
