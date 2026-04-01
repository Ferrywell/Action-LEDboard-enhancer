# Management — agent-handoffs & lead visibility

Doel: **geen copy-paste nodig** tussen parallelle Cursor-agenten en de lead developer (mens + lead-AI). Elke agent **schrijft hier** wat ze deden, wat openstaat en wat ze nodig hebben.

## Bestanden

| Bestand | Wie | Inhoud |
|---------|-----|--------|
| **[assignments/](assignments/README.md)** | **Lead + elke agent** | **Per agent een bestand** met *Huidige opdracht (lead)* en *Rapport (agent)* — **primaire manier** om opdrachten te geven zonder copy-paste. |
| [STATUS.md](STATUS.md) | **Alle agents** | Kort overzicht, blockers, sync na taken. |
| [LEAD-CYCLE.md](LEAD-CYCLE.md) | Jij + lead | Stappen: agent klaar → jij meldt bij lead → nieuwe opdrachten in `assignments/`. |
| [TEMPLATE-HANDOFF.md](TEMPLATE-HANDOFF.md) | Optioneel | Langere rapporten — kopieer naar `log/YYYY-MM-DD-<rol>.md` als nodig. |
| `log/` | Optioneel | Diepgaande handoffs, testlogs. |

## Afspraken

1. **Opdrachten:** staan in **`management/assignments/agent-*.md`** (sectie *Huidige opdracht (lead)*). Agents lezen **hun eigen** bestand.
2. **STATUS.md** blijft het snelle overzicht na elke taak.
3. **Blockers** in `STATUS.md` en/of in het rapport van de agent.
4. **Lead** werkt opdrachten bij na jouw seintje; zie [LEAD-CYCLE.md](LEAD-CYCLE.md).

## Hoe jij dit gebruikt (zonder copy-paste)

- **Agents:** één chat per agent; prompt staat in [assignments/README.md](assignments/README.md) (verwijst naar het juiste `agent-N-….md`).
- **Lead:** na rapporten — chat met lead-AI + [LEAD-CYCLE.md](LEAD-CYCLE.md); die vult **nieuwe** opdrachten in `assignments/`.
- Pin **`management/STATUS.md`** voor snel overzicht.

De Cursor-regel in `.cursor/rules/` herinnert agents aan STATUS + assignments.
