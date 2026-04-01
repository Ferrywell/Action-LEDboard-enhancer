# iOS-app (SwiftUI) — overzicht en gebruik

SwiftUI / **iOS 17+**-app onder `ios/` die als **BLE Central** werkt en dezelfde GATT-UUID’s en bytevolgorde volgt als `reference/panel-hopper-github/vendor/bk_light/display_session.py`. **Protocolconstanten niet wijzigen** zonder afstemming met de BLE-protocolreferentie.

## Module-overzicht

| Onderdeel | Locatie |
|-----------|---------|
| GATT + `buildFrame`, CRC32, command-ID ACK-matching | `ios/ActionLEDboard/BLE/BKLightProtocol.swift` |
| Scan `LED_BLE_*`, connect, notify, writes with response, chunking + timeouts, frame-ACK (`ackStageThree`) | `ios/ActionLEDboard/BLE/BKLightBleClient.swift` |
| 32×32 PNG-rendering (tekst + image-adjust) | `ios/ActionLEDboard/Rendering/PanelBitmapRenderer.swift` |
| EventKit (`requestFullAccessToEvents`, iOS 17) | `ios/ActionLEDboard/Services/CalendarEventsProvider.swift` |
| URLSession + OpenSky (geen API-key) | `ios/ActionLEDboard/Services/FlightBoardProvider.swift` |
| UI: kalender / bericht / vluchten + BLE-sectie | `ios/ActionLEDboard/ContentView.swift` |
| Rechten / background BLE | `ios/ActionLEDboard/Info.plist` (o.a. Bluetooth, agenda, `bluetooth-central`) |
| Xcode-project | `ios/ActionLEDboard.xcodeproj` |

## Openen en builden (Mac + Xcode)

1. Open **`ios/ActionLEDboard.xcodeproj`** op een Mac.
2. **Signing & Capabilities**: stel je team in (`DEVELOPMENT_TEAM` is standaard leeg).
3. **App-icoon:** staat in `Assets.xcassets/AppIcon` als `AppIcon-1024.png` (32×32 LED-rooster, amber op donker). Opnieuw genereren: `python tools/generate_app_icon.py` (vereist Pillow).
4. Fysiek apparaat met BLE gebruiken voor echte paneeltests.

### Signing (Xcode-waarschuwing “Select a development team”)

- Klik bij **Team** op **Add Account…** en log in met je **Apple ID** (gratis developer-account is genoeg voor eigen iPhone).
- Kies daarna je **Personal Team** of betaald team. Zonder team kun je **niet** naar een fysiek toestel deployen.
- **Bundle ID** (`com.actionled.ActionLEDboard`) moet uniek zijn voor jouw team; wijzig alleen als Xcode dat vraagt.

### Simulator vs echte iPhone (Bluetooth)

- **iOS Simulator** ondersteunt **geen** echte Bluetooth LE voor dit soort apps: `CBCentralManager` is vaak **unsupported**; in de console zie je o.a. `API MISUSE` / XPC-meldingen. Dat is **normaal**.
- **Test altijd op een echte iPhone** met Bluetooth aan voor scan/connect naar het paneel.
- De app toont een duidelijke melding als BLE niet beschikbaar is (o.a. Simulator of Bluetooth uit).

### “Untrusted Developer” op de iPhone

Als iOS een systeemvenster toont dat apps van **Apple Development: … (jouw e-mail)** niet zijn toegestaan:

1. Open **Instellingen** → **Algemeen** → **VPN en apparaatbeheer** (of **VPN & Device Management**; op sommige iOS-versies heet het **Profielen** / **Device Management**).
2. Tik onder **Developer App** op het profiel met jouw **Apple Development**-account.
3. Tik **Vertrouw …** / **Trust** en bevestig.

Daarna start de app normaal vanaf het homescreen. Dit hoort bij **gratis** Apple-ID-signing; het is geen fout in de projectcode.

### Xcode-fout `dyld_shared_cache_extract_dylibs failed` (code 908)

Dit komt van **Xcode** bij het **laden van systeem-symbolen** voor de **debugger** (`dscExtractor`; foutmelding noemt vaak `IDEDebugserverStartWorker`), **niet** van compile-fouten in jouw app. Komt voor bij **bèta-iOS** (bijv. 26.x), kleine **SDK/iOS-build-mismatches**, of Apple-toolingbugs — **ook met USB** (`device_transport = 0`). Kabel alleen lost het dus **niet gegarandeerd** op.

**Snelste workaround (meestal genoeg voor BLE-/paneeltesten): zonder debugger**

1. **Product → Scheme → Edit Scheme…**
2. Links **Run** → tab **Info**.
3. Zet **Debugger** op **None** (i.p.v. LLDB).
4. **Close** → **Run** (⌘R). Xcode start de app dan **zonder** debugserver-symbolen te hoeven extraheren — 908 verdwijnt meestal.

Alternatief: **⌘B** (Build), daarna de app op de iPhone **vanaf het homescreen** openen (na **Vertrouwen**). Geen breakpoints, wél testen.

**Als je LLDB wél nodig hebt:** Xcode/iOS naar de **nieuwste compatibele** combinaties updaten, Derived Data legen, toestel opnieuw koppelen; op **iOS-bèta** blijft dit soms een Apple-zijde issue.

**Overig:** **USB** blijft handig; **Derived Data** legen (**Settings → Locations → Derived Data**); optioneel **DeviceSupport** opnieuw laten opbouwen (`~/Library/Developer/Xcode/iOS DeviceSupport/` — voorzichtig). Zie ook [Apple’s release notes](https://developer.apple.com/documentation/xcode-release-notes).

### Volledig zwart scherm bij openen van de app

Op sommige **iOS-bèta’s** kan een enkele `Form` in `NavigationStack` een leeg of zwart scherm geven. De app gebruikt daarom een **`List`** met **`.listStyle(.insetGrouped)`** en een expliciete **systemGroupedBackground** op het venster. Na wijzigingen: opnieuw **builden en installeren**, daarna de app volledig **afsluiten** (app switcher) en opnieuw openen.

### “App verwijderd maar dezelfde Xcode-fout (908)”

**De app van de iPhone verwijderen** lost **`dyld_shared_cache_extract_dylibs failed`** niet op. Die fout komt van **Xcode op de Mac** (symbolen/debugserver), niet van geïnstalleerde data op het toestel. Wel helpen: **gedeeld scheme** in het project (**`ios/.../xcshareddata/xcschemes/ActionLEDboard.xcscheme`**) met **Run zonder debugger** en optioneel **`IDEPreferLogStreaming=YES`** — na `git pull` in Xcode het scheme **ActionLEDboard** kiezen en opnieuw Run.

## Gedrag t.o.v. het protocol

- **GATT na connect:** als binnen **18 seconden** geen schrijf- (`fa02`) en notify-kenmerk (`fa03`) gevonden worden, zet de app een begrijpelijke fout (`lastError`) en verbreekt de BLE-verbinding — geen oneindig “wachten op GATT” in de UI.
- **Scan:** alleen apparaten waarvan de **naam** het prefix **`LED_BLE_`** heeft (zoals in [HARDWARE.md](HARDWARE.md)).
- **Betrouwbare flow:** commando’s wachten op notifications die overeenkomen met AckWatcher-achtige logica (`isCommandAck`); frame-send wacht op `05 00 02 00 03` (stage three); handshake volgt Python (timeouts op handshake-stap 1/2 zijn niet noodzakelijk fataal).
- **Chunking:** lange payloads worden in stukken geschreven, begrensd door `maximumWriteValueLength(for: .withResponse)` en **`BKLightProtocol.bleWriteChunkSize` (500 B)** — dat zijn **ATT-schrijf**-subpackets, gelijk aan het Python-GIF-pad (`MTU_SIZE = 500` in `display_session.py`). **GIF-logische** chunks van **12 KB** (`gifChunkPayloadMax` / `CHUNK_SIZE` in Python) blijven het payloadformaat vóór die writes; zie [BLE-PROTOCOL.md](BLE-PROTOCOL.md).

## 16×32 (Action LED Pixel Scherm)

Zoals [HARDWARE.md](HARDWARE.md) en [BLE-PROTOCOL.md](BLE-PROTOCOL.md): de handshake bevat o.a. **`32 00`** in de 32×32-aanname. Voor **16×32** zijn de juiste bytes **niet** in upstream vastgelegd.

**Pas handshake/framebytes niet aan in de app** tot er BLE-captures of hardwaretests zijn. Ondersteuning voor 16×32 vereist: metingen of captures van de officiële app, daarna exact gelijk trekken met Python en documentatie.

## Optioneel later

- **Background:** naast `UIBackgroundModes` kan `CBCentralManagerOptionRestoreIdentifierKey` + state restoration helpen na suspend.
- **Vluchten:** OpenSky is **indicatief**; productie kan een eigen API + sleutels via URLSession.
- **Xcode:** gedeelde **XCScheme** of uitgebreidere vlucht-UI (eigen API, regio) kan later worden toegevoegd.

## Nog te doen voor TestFlight

### 1. App Store Connect / build / signing / app-icoon

*(Zonder Mac kun je onderstaande als checklist vastleggen; uitvoeren gebeurt op een Mac met Xcode / browser.)*

| Item | Waarde / actie |
|------|----------------|
| Xcode-project | `ios/ActionLEDboard.xcodeproj` openen op een Mac. |
| Bundle ID (target) | `com.actionled.ActionLEDboard` — zie `PRODUCT_BUNDLE_IDENTIFIER` in het Xcode-target (build settings). |
| Signing | **Signing & Capabilities** → *Automatically manage signing* → Apple Developer-team kiezen (vult `DEVELOPMENT_TEAM` in; repo-default is leeg). |
| Archive / upload | Menu **Product → Archive**, daarna Organizer → **Distribute App** → App Store Connect / TestFlight (Apple-documentatie volgen). |

**1024×1024 App Icon:** het toevoegen van het icoon in `Assets.xcassets` → **AppIcon** vereist **Xcode op een Mac** (PNG in de 1024×1024-slot slepen of asset-set aanvullen). Zonder Mac: alleen deze stap op de bouwmachine uitvoeren.

### 2. Privacy (usage descriptions & store)

*(Teksten en keys kun je in de repo reviewen; App Store-formulieren invullen gebeurt in App Store Connect.)*

| Sleutel | Bestand | Huidige NL-tekst (review t.o.v. App Store-eisen) |
|---------|---------|---------------------------------------------------|
| `NSBluetoothAlwaysUsageDescription` | `ios/ActionLEDboard/Info.plist` | Bluetooth is nodig om verbinding te maken met BK-Light LED-panelen (naam begint met LED_BLE_). |
| `NSCalendarsFullAccessUsageDescription` | idem | Agenda-items kunnen op het pixelbord worden getoond. |

- **Privacy Nutrition Labels** (App Store Connect): naar waarheid invullen o.a. *Bluetooth* (verbinding met randapparaat), *Agenda* (alleen als kalendermodus gebruikt wordt), *Netwerk* (vluchtmodus via URLSession/OpenSky). Exacte categorieën volgens Apple’s vragenlijst bij upload.
- **Export / encryptie:** `ITSAppUsesNonExemptEncryption` = `false` in `Info.plist` — bij release bevestigen dat dit nog steeds klopt voor de app-inhoud.

### 3. Functionaliteit (scope)

- **GIF-upload naar het paneel** zit in de Python-referentie (`send_gif` in `display_session.py`) maar **niet** in de huidige iOS-UI; blijft buiten scope tenzij expliciet opgenomen.

### 4. QA

- Paneeltests op **fysiek apparaat** (simulator heeft geen echte BLE naar hardware); eventueel TestFlight-interne testers + checklist uit [QA-RELEASE.md](../QA-RELEASE.md).

## Zie ook

- [IOS-BLE-SEQUENCES.md](IOS-BLE-SEQUENCES.md) — byte-volgordes en timing  
- [PLATFORM-BLE.md](PLATFORM-BLE.md) — iOS vs andere platforms  
- [QA-RELEASE.md](../QA-RELEASE.md) — testen Python vs iOS  
