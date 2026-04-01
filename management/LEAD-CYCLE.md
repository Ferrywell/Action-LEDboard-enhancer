# Werkwijze: jij ↔ lead ↔ agents

## Jij geeft agents individueel werk

1. Open **één Composer-chat per agent** (geen vier agents in één chat als je strikte opdrachten wilt).
2. Plak de **vaste prompt** uit [assignments/README.md](assignments/README.md) en kies het juiste `agent-N-….md`-bestand.
3. De agent leest **alleen** dat bestand, werkt de sectie **Huidige opdracht (lead)** af, vult **Rapport (agent)** in.

## Jij rapporteert aan de lead (AI)

Wanneer een of meer agents klaar zijn:

```text
Agent(en) N (en M) zijn klaar. Lees management/assignments/agent-N-….md (Rapport-secties) en management/STATUS.md. Geef de volgende ronde opdrachten in de « Huidige opdracht (lead) » secties en zet in STATUS wat ik moet weten. Zeg expliciet of mijn (Ferry’s) feedback nodig is of dat we naar hardware-test kunnen.
```

De lead werkt dan de opdrachtenbestanden bij; jij start de volgende ronde met dezelfde vaste prompt per agent.

## Waar de lead schrijft

- **Alleen** in `management/assignments/agent-*.md` → blok **Huidige opdracht (lead)**.
- Optioneel: korte update in `management/STATUS.md` (prioriteit / blockers).

## Einde van de lus

Stop wanneer de lead zegt: feedback van jou nodig, of: klaar om op paneel/iPhone te testen.
