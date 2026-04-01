# Hardware: Action BK-Light panelen

## Fabrikant / type

Panel Hopper richt zich op **BK-Light ACT1026**-achtige RGB LED-boards met **Bluetooth Low Energy**. De firmware laat zich typisch zien als BLE-peripheral met naam **`LED_BLE_*`**.

## Twee Action-varianten (Nederland)

| Product | Resolutie | Status in Panel Hopper (upstream) |
|---------|-----------|-------------------------------------|
| [LED Pixelbord](https://www.action.com/nl-nl/p/3217439/led-pixelbord/) | **32×32** (vierkant) | Ondersteund: beeld, tekst, GIF (zie repo), grid met meerdere panelen. |
| [LED Pixel Scherm](https://www.action.com/nl-nl/p/3217438/led-pixel-scherm/) | **16×32** (langwerpig) | **Gepland** — expliciet genoemd in `README.md` als toekomstige update. |

## Wat dat praktisch betekent

- **32×32**: Handshake en frames in `display_session.py` gebruiken waarden die passen bij **32×32** (o.a. bytes `32 00` in `HANDSHAKE_FIRST` / ACK — zie [BLE-PROTOCOL.md](BLE-PROTOCOL.md)).
- **16×32**: Zolang upstream geen aparte modus shipt, is **niet gegarandeerd** dat dezelfde bytes werken. Waarschijnlijk zijn er **andere handshake- of frameparameters**; dat moet worden **gemeten** (BLE-capture met officiële app) of **reverse-engineered** wanneer ondersteuning wordt toegevoegd. Zie [16x32-HARDWARE.md](16x32-HARDWARE.md).

## Bluetooth-adapter (PC)

Zelfde eisen als in Panel Hopper: **BLE 4.0+**, **central / GATT client**, lange ATT-writes. Op Windows vaak **terminal als Administrator** voor betrouwbare toegang.

## iPhone

Het paneel blijft BLE-peripheral; een iOS-app wordt **central** (CoreBluetooth). Zie algemene architectuur in projectdiscussie — niet specifiek in deze hardwarepagina uitgewerkt.
