# BLE-tools (PC)

Bronimplementatie: `reference/panel-hopper-github/vendor/bk_light/display_session.py`.

## Setup

```powershell
cd tools/ble
pip install -r requirements.txt
```

## Test-PNG genereren (32×32)

```powershell
python generate_test_png.py -o test_pattern_32x32.png
```

## Naar paneel sturen

```powershell
$env:BK_LIGHT_ADDRESS = "AA:BB:CC:DD:EE:FF"   # Windows MAC-formaat
python send_to_panel.py test_pattern_32x32.png
python send_to_panel.py -v --brightness 70 animation.gif
```

Zonder adres: foutmelding — zet `BK_LIGHT_ADDRESS` of `-a`.

**Delay:** zonder `--delay` geldt hetzelfde als `BleDisplaySession`: **0,2 s** tussen stappen bij PNG (`send_png`), **0,05 s** bij GIF (`send_gif`). Overschrijf met `--delay <sec>` voor beide paden.

## Protocoltests (repo-root)

```powershell
cd ../..
pip install -r requirements-dev.txt
pytest tests/test_ble_protocol.py -v
```

Hardware is niet nodig voor bovenstaande tests.

## Parity met iPhone (zelfde fysieke paneel)

Gebruik **één** 32×32 Action Pixelbord (`LED_BLE_*`). Doel: vaststellen dat PC-tool en iOS-app hetzelfde protocolgedrag op het **zichtbare** resultaat afspiegelen.

### Aanbevolen volgorde

1. **Eerst Python:** genereer een test-PNG (`generate_test_png.py`) en stuur die met `send_to_panel.py` naar het paneel. Noteer helderheid, eventueel `-v` voor notifies.
2. **Daarna iOS:** stuur **dezelfde pixelinhoud** (zelfde 32×32 bitmap — export/import PNG in de app of reproduseer het quadrant-patroon in de iOS-renderer). Gebruik dezelfde BLE-sessie niet tegelijk; disconnect de PC-tool voordat je op de iPhone verbindt, of omgekeerd, zodat het paneel maar één central tegelijk bedient.

### Wat op het paneel gelijk moet zijn (functioneel)

- **Statisch beeld:** dezelfde vier kwadranten/kleuren op dezelfde posities (eventueel kleine verschillen door PNG-encoding/gamma zijn acceptabel zolang het patroon herkenbaar hetzelfde is).
- **Helderheid:** bij dezelfde percentage-instellingsstappen vergelijkbaar visueel gedrag (LED-discrete stappen kunnen kleine verschillen geven).
- **Reconnect / tweede send:** na opnieuw verbinden moet een tweede upload weer het verwachte beeld tonen (zie scenario’s **C / R / B / S** in de testmatrix).

### Waar de volledige matrix staat

De uitgebreide **Python vs iOS**-testmatrix (scenario-ID’s **C, R, B, S, G, M**), succescriteria en escalatie staat in **[`docs/QA-RELEASE.md`](../../docs/QA-RELEASE.md)** (sectie *Testmatrix: Python vs iOS* en de scenario-tabellen). Voor dit repo gebruik je voor de Python-kant concreet **`tools/ble/send_to_panel.py`** in plaats van of naast panel-hopper CLI/web — protocolbytes volgen nog steeds `display_session.py`.

**Let op:** GIF-pariteit en grotere scenario’s volgen dezelfde matrix; **16×32** blijft exploratief tot vastgelegd in hardware-docs ([`docs/reference/HARDWARE.md`](../../docs/reference/HARDWARE.md)).
