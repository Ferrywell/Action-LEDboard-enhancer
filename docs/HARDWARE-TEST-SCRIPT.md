# Hardwaretest-script (Ferry) — ~15–20 min

Korte handleiding voor een eerste **echte** run met **Action 32×32-paneel** (`LED_BLE_*`) en **iPhone**. Uitgebreide scenario’s en ID’s staan in **[QA-RELEASE.md](QA-RELEASE.md)** (o.a. **C** = connect, **R** = reconnect, **S** = statisch beeld, **B** = helderheid).

---

## Voor je start

- **Paneel:** opladen / van stroom voorzien; binnen **~5 meter** van iPhone (en eventueel PC).
- **iPhone:** **Bluetooth aan** (Instellingen → Bluetooth); locatie niet vereist voor alleen BLE, maar BT moet echt aan staan.
- **App:** TestFlight- of debug-build van Action LEDboard openen.
- **PC (optioneel):** alleen nodig voor vergelijk **Python-send** — zie [§ Optioneel: zelfde PNG via PC](#optioneel-dezelfde-test-png-via-pc).

---

## A — iPhone: scan → connect → PNG sturen (~10 min)

1. **App openen** — wacht tot het hoofdscherm zichtbaar is (geen crash).
2. **Bluetooth-permissie** — als gevraagd: toestaan.
3. **Scan** — start scan; wacht tot **`LED_BLE_...`** in de lijst staat.  
   - *Gerelateerd QA-scenario:* **C1** (eerste koppeling), **C2** (geen paneel: lege lijst is OK om te zien hoe de app reageert — niet per se nu testen).
4. **Connect** — tik op het paneel; wacht op **verbonden** (geen eeuwige spinner zonder foutmelding).
5. **Statisch beeld** — kies een **PNG** (of ingebouwde test / upload, afhankelijk van de build) en **verstuur** naar het paneel.  
   - *Gerelateerd:* **S1** (standaard PNG), **S3** als je een groter bronbestand probeert.
6. **Check op het paneel** — beeld zichtbaar, geen halve matrix of vastgelopen state.
7. *(Kort)* **Helderheid** — als de UI dat heeft: min/max of een tussentrap.  
   - *Gerelateerd:* **B1–B2** in QA-RELEASE.

**Klaar als:** connect + één geslaagde PNG-send zichtbaar op hardware.

---

## B — Optioneel: dezelfde test-PNG via PC (~5–10 min)

Doel: **vergelijking** Python-tool ↔ iOS op **hetzelfde** fysieke paneel (niet tegelijk verbonden — één central per paneel).

1. **Paneel loskoppelen van iPhone** — in de app disconnecten, of app sluiten / BT tijdelijk uit op de telefoon zodat de PC verbinding kan maken.
2. **PC-setup** — vanaf repo-root (zie `tools/ble/README.md`):
   - `cd tools/ble`
   - `pip install -r requirements.txt` (eenmalig)
   - Genereer test-PNG: `python generate_test_png.py -o test_pattern_32x32.png`
3. **MAC-adres** — in Systeeminstellingen of eerdere scan: MAC van het paneel noteren.  
   - Windows PowerShell:  
     `$env:BK_LIGHT_ADDRESS = "AA:BB:CC:DD:EE:FF"`  
     (vervang door jouw MAC, formaat met dubbele punten)
4. **Versturen:**  
   `python send_to_panel.py test_pattern_32x32.png`
5. **Visueel vergelijken** — het patroon op het paneel zou het **herkenbaarzelfde** moeten zijn als bij iOS (kleine encoder/gamma-verschillen kunnen). Zie QA-RELEASE *Testmatrix: Python vs iOS* en `tools/ble/README.md` sectie *Parity met iPhone*.

---

## Na afloop

- Noteer kort: **gelukt / niet**, **welk device** (iPhone-model, iOS), **eventuele fouttekst** in de app.
- Resultaat kort delen met de lead (chat of PR) — geen uitgebreid rapport nodig tenzij er blokkers zijn.

---

## Bekende randvoorwaarden

- **Windows:** voor betrouwbare BLE soms terminal **als Administrator** (`tools/ble/README.md`, [QA-RELEASE.md](QA-RELEASE.md) hardware-sectie).
- **GIF op iOS** kan in bepaalde builds nog **out-of-scope** zijn — check projectstatus / lead.
- **16×32-paneel:** niet als “moet slagen” behandelen tot protocol/hardware vastligt ([reference/HARDWARE.md](reference/HARDWARE.md)).
