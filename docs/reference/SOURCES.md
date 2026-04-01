# Bronnen en locaties

## GitHub (actueel)

| Item | URL / notitie |
|------|----------------|
| **Panel Hopper** (Python, BLE, web) | https://github.com/Ferrywell/panel-hopper |
| **Bk-Light-AppBypass** (oorspronkelijke toolkit) | https://github.com/Pupariaa/Bk-Light-AppBypass |
| **Puparia** (credits reverse-engineering) | https://github.com/Pupariaa |

Panel Hopper README vermeldt:

- Statisch beeld / basis BLE voortgebouwd op **Bk-Light-AppBypass**.
- **GIF-animatieprotocol** afgeleid van **iPixel Color** via **BLE capture analysis** (niet alleen decompilatie).

## Lokale kopie in dit project

| Pad | Doel |
|-----|------|
| `reference/panel-hopper-github/` | Shallow clone van `Ferrywell/panel-hopper` voor naslag (o.a. langwerpig paneel + iPixel in README, uitgebreide `display_session.py`). |

Bijwerken:

```bash
cd reference/panel-hopper-github
git pull
```

Opnieuw clonen (schone staat):

```bash
rm -rf reference/panel-hopper-github   # of verwijder map in Verkenner
git clone --depth 1 https://github.com/Ferrywell/panel-hopper.git reference/panel-hopper-github
```

## Oudere lokale backup (niet in deze repo)

Je hebt eerder een Cursor-projectbackup gebruikt op o.a.:

`C:\Users\ferry\Desktop\rest\paneel hopper backup (met data)\`

Die versie is **ouder** dan de huidige GitHub `main`: minder iPixel-commentaar in `display_session.py`, geen uitgebreide GIF-logica in dezelfde vorm. Gebruik GitHub als **primair** voor protocoldetails; de backup blijft nuttig voor `panels.json`, `.venv`, en eventuele lokale aanpassingen.

## Action NL (productpagina’s in Panel Hopper README)

- **32×32 — LED Pixelbord** — https://www.action.com/nl-nl/p/3217439/led-pixelbord/  
- **16×32 — LED Pixel Scherm** (langwerpig) — https://www.action.com/nl-nl/p/3217438/led-pixel-scherm/  

Status in upstream: 32×32 ondersteund; 16×32 **gepland** (zie [HARDWARE.md](HARDWARE.md)).
