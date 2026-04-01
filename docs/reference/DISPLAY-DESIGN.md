# Informatiedesign — 32×32 LED-paneel

Richtlijn die aansluit op [BLE-PROTOCOL.md](BLE-PROTOCOL.md) en de patronen in `reference/panel-hopper-github/src/panel_hopper/graphics.py` (o.a. 5×7 dot-matrix, `PANEL_SIZE = 32`).

---

## Canvas en leesbaarheid op afstand

| Parameter | 32×32 | Richtlijn |
|-----------|-------|-----------|
| Pixelpitch | 1 “dot” = 1 RGB-pixel | Alles is grof; detail verliest snel. |
| Veilige tekst | 5×7 dot + 1 px tussenruimte per teken | Zie `DOT_MATRIX_FONT`: `CHAR_WIDTH=5`, `CHAR_HEIGHT=7`, `CHAR_SPACING=1` → ~6 px breed per teken bij scale 1. |
| Max. tekens op één rij (scale 1) | ca. 5 tekens (30 px + marge) | Bij scale 2 (repo probeert 4→1): 2 tekens per rij — dan is multiline of scroll nodig. |
| Twee regels (scale 1) | 7 + 1 + 7 = 15 px hoog + tussenruimte | Past net in 32 px; dan weinig verticale marge. |
| Contrast | — | Voorkeur: amber/oranje op zwart (`#ff9900`) — zoals highway signs. Vermijd lichtgrijs op wit; op LED oogt “midden” snel wazig. |
| Kleur | — | 1 primaire signaalkleur + zwart. Tweede kleur alleen voor accent (bijv. rood = waarschuwing), niet voor lange zinnen. |

**Bitmap vs. vector-font:** Op dit formaat wint vaste dot-matrix (`create_dot_matrix_text`) boven truetype: geen halftinten-raster, scherpe “LED-segmenten”. Systeemfonts (`create_text_image`, default ~18 pt) zijn handig voor prototyping; voor productie op het paneel liever dot-matrix of zwaar gebold + NEAREST na downscale.

---

## Statisch (PNG) vs. geanimeerd (GIF) — afgestemd op BLE

| Doel | Transport | Protocolnotities |
|------|-----------|------------------|
| Eén toestand (datum, vast bericht, “nu”) | PNG | `DATA_TYPE_IMAGE` (`0x02,0x00`), extra byte `0x00`, na `CMD_EDIT_END`; optioneel eerst `set_display_mode(1)` om oude GIF te stoppen. |
| Scroll, wisselende regels, ticker | GIF (meerdere frames) | `DATA_TYPE_GIF` (`0x03,0x00`), extra `0x02`, ruwe GIF-bytes; chunks 12 KB met ACK’s; daarna display-/animate-commando’s. |
| Zelfde info, alleen periodiek verversen | PNG herhalen vanuit de app | Geen GIF nodig als er geen intra-frame animatie is. |

**Regel:** Gebruik GIF als de inhoud pas klopt door tijd (scroll of pagina’s); gebruik PNG als één frame genoeg is.

---

## Per feature: wat past, hoe niet

### 1. Datum

| Past | Past niet / oppassen |
|------|----------------------|
| Dag + maand afkorting: `1 APR`, `01-04` | Volledige maandnamen (“woensdag 1 april 2026”) |
| Compact ISO-achtig: `04-01` of `1 IV` | Twee regels kleine tekst zonder hiërarchie |

**Layout (32×32):**

- Voorkeur: één regel dot-matrix scale 2–3 voor `1 APR` of `01/04` (4–5 tekens), of twee regels scale 1: boven dag (`01`), onder maand (`APR`).
- Kleur: amber op zwart; optioneel dag iets feller dan maand (zelfde tint, geen tweede “leeskleur”).
- Transport: meestal PNG (1× per dag of bij wijziging).

### 2. Agenda-hint

| Past | Past niet |
|------|-----------|
| Tijd + 1 teken hint: `14³` = 14:00 derde item, of `9:¹` | Volledige titel |
| Initialen + uur: `9 Jd` (Jan d.) | Lange namen |
| Alleen “volgende”: `NEXT 15:00` → past niet in 5 tekens; beter `15:00` of `3PM` | Meerdere afspraken tegelijk |

**Layout:**

- Eén regel: max. 5 tekens @ scale 1, of kortere code @ scale 2.
- Twee regels: boven tijd (`15:30`), onder 2–3 letter projectcode (`MTG`).

**Transport:** PNG bij update; als je meerdere hints wilt afwisselen, gebruik een GIF met 2–3 frames (langzame delay, bv. 2–3 s) of één PNG die je vanuit de app wisselt.

### 3. Vluchten

| Past | Past niet |
|------|-----------|
| IATA + tijd: `KL 14:05` → te lang voor één regel | Volledige bestemming |
| Alleen flight number: `KL1234` (7 tekens) → niet op één regel @ scale 1 | Terminal + gate + bagage in één scherm |
| Scroll/ticker: volledige string in GIF met horizontale scroll | Statisch alles tonen |

**Aanpak:**

- Statisch: alleen `KL1234` (knip naar wat in 5 tekens past) of `1234` + airline icoon-bitmap (2–3 kleuren) in hoekje.
- Vollediger: GIF met 32×32 frames: tekstbitmap die 1 px per frame schuift (of page-flip: frame 1 = flight, frame 2 = bestemming afkorting `AMS`).
- Contrast: wit/amber op zwart; geen dunne lijnen (vliegtuig-iconen alleen als 3–4 blokjes).

### 4. Vrije tekst

| Past | Past niet |
|------|-----------|
| Korte slogan: `OK` `HI` `BUS` | Zinnen |
| Afkortingen + scroll | Paragraaf |

**Aanpak:**

- ≤5 tekens: center, dot-matrix, PNG.
- Langer: horizontale scroll-GIF (veel frames, kleine file door weinig kleuren + repeat) of verticale “tick” (2 regels die omwisselen) als 2-frame GIF.
- Alternatief: app stuurt elke N seconden nieuwe PNG (zelfde BLE-pad, geen GIF) — eenvoudiger, maar meer BLE-verkeer.

---

## Concrete afmetingen (samenvatting)

| Element | Afmeting |
|---------|----------|
| Canvas | 32 × 32 px RGB (upstream: handshake `32 00`) |
| Dot-matrix cel | 5 × 7 px per teken + 1 px tussenruimte |
| Bruikbare “marge” | ~2 px van rand (zoals in `create_dot_matrix_text`: `width - 2`) |
| Rijen tekst @ scale 1 | 1 rij: tot ~5 tekens; 2 rijen: ~2× kortere strings |
| `auto_scale` in repo | Probeert scale 4→1 voor maximale leesbaarheid binnen canvas |

---

## Pipeline: app-data → PNG/GIF → protocol

1. **Data → view-model**  
   Normaliseer naar vaste velden (`title`, `time`, `line1`, `line2`, `mode: static|scroll`).

2. **Render (PIL)**  
   - Canvas `Image.new('RGB', (32, 32), (0,0,0))`.  
   - Tekst: `create_dot_matrix_text` of handmatig `draw_dot_matrix_text` met vaste scale.  
   - Geen halftransparantie: RGB vol.

3. **Optioneel**  
   Helderheid/contrast in app of via `adjust_image` (brightness/rotatie in `display_session.py`).

4. **Export**  
   - **PNG:** `to_png_bytes(img)` → `build_frame(png_bytes, is_gif_frame=False)` → write + ACK.  
   - **GIF:** frames elk 32×32, palette GIF, `Image.save(..., save_all=True)` → bytes → `build_frame(..., is_gif_frame=True)` + chunking volgens repo.

5. **BLE-volgorde (statisch)**  
   Zoals in naslag: animatie stoppen → handshake → `CMD_EDIT_END` → frame met PNG.

---

## Implementatie (iOS)

De Swift-module `ios/ActionLEDboard/Rendering/PanelBitmapRenderer.swift` volgt het **32×32**-canvas en levert **PNG-bytes**; dat sluit aan op het statische beeld in [BLE-PROTOCOL.md](BLE-PROTOCOL.md). `panelSize` is vast **32×32**; 16×32 wordt in code expliciet niet geraden (consistent met [16x32-HARDWARE.md](16x32-HARDWARE.md)).

**Al in lijn met dit document:** één bitmap per update; zwarte achtergrond bij tekst (`renderLines`); beperkte marge via een inset (`y: 2`, hoogte `panelSize.height - 4`), vergelijkbaar met de ~2 px rand in de Python dot-matrix helper; meerdere regels via `lines.joined(separator: "\n")` — passend bij “max. twee regels × korte tokens” zolang de aanroeper de array kort houdt. `adjustPNG` past **rotatie** en een **helderheidsfactor** toe vóór PNG-export; dat komt overeen met het idee van `adjust_image` in de Python-kant (wel andere techniek: hier `cgContext.setAlpha` op de getekende `UIImage`, geen PIL `ImageEnhance`).

**Standaardkleuren (tekst):** `renderLines` gebruikt standaard **wit** op **zwart** (`PanelBitmapRenderer.defaultTextForeground`) voor hoog contrast op discrete LEDs. Aanroepers kunnen `foreground`/`background` overschrijven. **`adjustPNG`** zet geen tekstkleur: het schaalt/rotereert alleen de aangeleverde bitmap en past helderheid toe; kleur zit in de pixeldata.

**Tekstweergave:** `renderLines` gebruikt een **5×7 dot-matrix** (gelijnd met `panel_hopper` / `DotMatrixFont`) zodat bitmappixels 1:1 bij LEDs passen. Automatische schaal 1–4 binnen 32×32; te veel tekst wordt klein of visueel onleesbaar — houd regels en tokens kort. **GIF**-opbouw in deze module: zie roadmap / toekomstige iOS-implementatie.

---

## 16×32 (toekomst)

Nog geen vaste handshake in upstream: ontwerp layouts modulair (breedte/hoogte parameters), maar reken op **16 px breed**:

- Dot-matrix @ scale 1: ~2 tekens per rij; twee kolommen layouts zijn nauwelijks haalbaar.
- Gebruik 2 regels of verticale scroll-GIF eerder dan horizontaal.

Zie ook [16x32-HARDWARE.md](16x32-HARDWARE.md).

---

## Kern

Beperk elk scherm tot **één boodschap**, maximaal **twee regels × korte tokens**; gebruik **GIF** alleen waar beweging of afwisseling nodig is; houd **één signaalkleur op zwart** voor leesbaarheid op afstand.
