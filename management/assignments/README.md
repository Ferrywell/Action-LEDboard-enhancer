# Opdrachten per agent (lead → uitvoering → rapport)

## Rollen

| Bestand | Rol |
|---------|-----|
| [agent-1-ios.md](agent-1-ios.md) | iOS / Swift / CoreBluetooth |
| [agent-2-ble-protocol.md](agent-2-ble-protocol.md) | BLE-protocol & Python-tools |
| [agent-3-micro-display-ux.md](agent-3-micro-display-ux.md) | Micro-display UX & graphics |
| [agent-4-qa-release.md](agent-4-qa-release.md) | QA & release |

## Workflow (jij + lead-AI + agents)

1. **Lead** (Cursor-chat met de lead-developer AI) schrijft of wijzigt alleen het blok **« Huidige opdracht (lead) »** in het juiste `agent-*.md`-bestand. Eventueel korte notitie in [../STATUS.md](../STATUS.md).
2. **Jij** opent een **aparte** Composer-chat per agent en geeft **één vaste instructie** (zie onder) zodat die agent **alleen zijn/haar bestand** als bron van opdracht gebruikt.
3. De **agent** voert uit, vult **« Rapport (agent) »** in hetzelfde bestand in (en bij voorkeur [../STATUS.md](../STATUS.md)).
4. **Jij** rapporteert aan de **lead**: *“Agent N is klaar — lees `management/assignments/agent-N-….md` en STATUS.”*
5. **Lead** leest rapporten, zet **nieuwe** opdrachten in de opdrachtenbestanden, en markeert eventueel wat er getest moet worden of welke feedback jij moet geven.
6. Herhaal tot de lead aangeeft: **feedback van jou nodig**, **klaar voor test op hardware**, of **stop**.

Zo hoef je geen lange chat-logs te copy-pasten: de waarheid staat in `assignments/` + `STATUS.md`.

## Korte prompts (aanbevolen)

Alle vaste **één-regel-prompts** staan in **[PROMPTS.md](PROMPTS.md)** — kopieer daar per agent één regel; geen aanpassen nodig.

Langere uitleg (optioneel):

```text
Lees het volledige bestand management/assignments/agent-N-....md. Voer uitsluitend de opdracht uit in de sectie « Huidige opdracht (lead) ». Vul daarna de sectie « Rapport (agent) » in datzelfde bestand in (wat je deed, welke bestanden, open punten). Werk ook management/STATUS.md bij in jouw agent-sectie. Geen andere opdrachten dan wat in dat bestand staat.
```

Bestandsnamen: `agent-1-ios.md` … `agent-4-qa-release.md` (zie [PROMPTS.md](PROMPTS.md)).

## Lead: na binnenkomst rapporten

Gebruik in een chat met de lead-AI bijvoorbeeld:

```text
Agents hebben gerapporteerd. Lees management/STATUS.md en alle management/assignments/agent-*.md (secties Rapport). Geef nieuwe opdrachten in de « Huidige opdracht (lead) » secties en noteer of Ferry feedback moet geven of we naar hardware-test kunnen.
```
