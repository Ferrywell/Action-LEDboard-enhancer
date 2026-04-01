# 16×32 (LED Pixel Scherm) — alleen hardware

**Status**: Geen gecommit protocolconstanten in deze repo voor **16×32**; upstream Panel Hopper noemt dit als toekomstige update.

## Wat we niet doen

- **Geen** handshake- of frame-bytes **gokken** voor 16×32 op basis van 32×32.
- **Geen** automatische tests in CI die zonder paneel beweren dat 16×32 werkt.

## Wat wel (wanneer hardware beschikbaar is)

1. **BLE-capture** met de officiële app (iPixel Color / fabrikant) op een **16×32** paneel: vergelijk handshake en eerste frame met `HANDSHAKE_FIRST` / `ACK_STAGE_ONE` in `display_session.py`.
2. Noteer **exacte hex** in dit bestand of in `BLE-PROTOCOL.md` onder een aparte sectie **“16×32 — bevestigd op hardware”** met datum en firmware-indicatie.
3. Optioneel: pytest **hardware**-marker (`pytest -m hardware`) — alleen lokaal met `BK_LIGHT_ADDRESS` + env-flag.

## 32×32 referentie (ter vergelijking)

Handshake eerste packet bevat o.a. `32 00` (zie `HANDSHAKE_FIRST` in `display_session.py`). Voor 16×32 is **onbekend** of `16 00`, `20 00`, product-id elders, of meerdere bytes wijzigen — **meet** op apparaat.
