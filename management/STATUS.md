# Projectstatus — Action-LEDboard-enhancer

*Laatste update: 2026-04-01 — roadmap actief; hardware informeel OK*

**Roadmap (planner):** [ROADMAP.md](ROADMAP.md) · **Opdrachten:** [assignments/](assignments/README.md) · **Test:** [docs/HARDWARE-TEST-SCRIPT.md](../docs/HARDWARE-TEST-SCRIPT.md)

## Lead / product

- **Nu:** **Fase A** — hardwaretest-script formeel afronden en onderstaand blok invullen (ook als alles al werkt).
- **Daarna:** **Fase B** (TestFlight/QA) volgens [ROADMAP.md](ROADMAP.md); agents volgen `agent-*.md`.

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

- Datum test:
- Paneel + iPhone: werkt / werkt niet (kort):
- Python parity (`send_to_panel`) getest: ja / nee / n.v.t.
- Opmerkingen voor lead:

*Notitie 2026-04-01: BLE + dot-matrix tekst zijn in de praktijk positief bevonden; formele doorloop van [HARDWARE-TEST-SCRIPT.md](../docs/HARDWARE-TEST-SCRIPT.md) blijft aanbevolen voordat Fase B als “af” geldt.*

---

## Volgende stappen (planner)

1. **Fase A:** [HARDWARE-TEST-SCRIPT.md](../docs/HARDWARE-TEST-SCRIPT.md) + blok hierboven invullen.
2. **Fase B:** TestFlight + QA — zie [ROADMAP.md](ROADMAP.md) Fase B.
3. **Fase C:** GIF op iOS — zie [ROADMAP.md](ROADMAP.md) Fase C.
4. **Fase D:** helderheid/UX — zie [ROADMAP.md](ROADMAP.md) Fase D.
