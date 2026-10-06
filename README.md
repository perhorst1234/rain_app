# RainBar Nederlands

Lokale uitbreiding van [RainBar van Nicolò Candiani](https://github.com/nicolocandiani/rain_app), versie 1.1.0.

- Nederlandstalige menubalk en bediening, met actuele temperatuur naast regenstatus.
- **Regen**: Buienradar-verwachting per vijf minuten voor de komende twee uur.
- **Weer**: huidige temperatuur, gevoelstemperatuur, dag-/nachtsymbolen, temperatuurverloop voor twaalf uur en een vijfdaags vooruitzicht met minimum, maximum en zonuren.
- Gedeelde locatiekeuze en automatische verversing elke vijf minuten. De laatst gekozen tab blijft bewaard.
- Native macOS-glasstijl in beide tabs.

Weerdata: [Open-Meteo](https://open-meteo.com/), met [API-documentatie](https://open-meteo.com/en/docs). Zonuren zijn verwachte uren zon voor de volledige dag, geen zonkanspercentage. Regengegevens: [Buienradar](https://www.buienradar.nl/). Geen API-sleutel nodig. Locatievoorzieningen zijn optioneel; je kunt een stad kiezen.

## Downloaden en installeren

Download [RainBar-NL-v1.1.0-universal.zip](https://github.com/perhorst1234/rain_app/releases/download/v1.1.0/RainBar-NL-v1.1.0-universal.zip) uit [Releases](https://github.com/perhorst1234/rain_app/releases).

1. Gebruik een Mac met **macOS 26 (Tahoe) of nieuwer**. De download bevat zowel Intel (`x86_64`) als Apple Silicon (`arm64`); Rosetta is niet nodig op Apple Silicon.
2. Pak de ZIP uit en sleep **RainBar.app** naar **Programma’s**.
3. Start RainBar. De app verschijnt in de menubalk. Kies een stad en wissel tussen **Regen** en **Weer**.

Deze persoonlijke build is ad-hoc ondertekend en niet door Apple genotariseerd. Als macOS de eerste keer openen blokkeert, kun je na de eerste startpoging via **Systeeminstellingen → Privacy en beveiliging → Open toch** toestemming geven voor deze app. Zie [Apple’s instructies](https://support.apple.com/102445). Een Developer ID-certificaat is niet inbegrepen.

De `SHA256SUMS.txt` bij de release bevat de checksum van de download. De originele broncode en MIT-licentie blijven behouden in deze fork.

## Bouwen

macOS 26+ en Xcode 26+ vereist. Open `RainBar.xcodeproj` en bouw RainBar, of bouw lokaal voor Intel en Apple Silicon:

```sh
xcodebuild -project RainBar.xcodeproj -scheme RainBar -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build \
  ARCHS='x86_64 arm64' ONLY_ACTIVE_ARCH=NO CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
```

App staat daarna in `build/Build/Products/Release/RainBar.app`. Dit is een lokale ad-hoc ondertekende build.

## Functionele checks

Voer uit vanuit deze broncodemap:

```sh
swiftc -parse-as-library RainBar/RainService.swift RainBar/WeatherService.swift \
  Tests/ForecastChecks.swift -o /tmp/rainbar-checks
/tmp/rainbar-checks
```

Checks testen JSON-decoding, zonuren, nachtweergave, Nederlandse regenstatus, foutafhandeling, locatie-wissels en vertraagde antwoorden. De laatste twee checks halen live gegevens op van Open-Meteo en Buienradar.

## Licentie

MIT; zie LICENSE. Open-Meteo-data valt onder de voorwaarden van Open-Meteo, met bronvermelding in de app.
