# RainBar Nederlands

Lokale uitbreiding van [RainBar van Nicolò Candiani](https://github.com/nicolocandiani/rain_app), versie 1.2.0.

- Nederlandstalige menubalk en bediening, met actuele temperatuur naast regenstatus.
- **Regen**: Buienradar-verwachting per vijf minuten voor de komende twee uur.
- **Weer**: huidige temperatuur, gevoelstemperatuur, dag-/nachtsymbolen, temperatuurverloop voor twaalf uur en een vijfdaags vooruitzicht met minimum, maximum en zonuren.
- Gedeelde locatiekeuze en automatische verversing elke vijf minuten. Bij openen verschijnt **Regen** als regen verwacht wordt, anders **Weer**. Handmatig wisselen blijft mogelijk zolang het venster openstaat.
- Compacte bovenbalk met beide tabs en een venster dat zich aan de inhoud aanpast.
- Lichte regen blijft zichtbaar door een passende, gelabelde grafiekschaal.
- Klik op Vandaag, Morgen of een weekdag voor uurdetails: temperatuur, gevoelstemperatuur, regenkans, neerslag en wind. Filter op ochtend, middag of avond; wegklikken sluit de details.
- Ondertekende automatische updates uit deze fork via Sparkle.

Weerdata: [Open-Meteo](https://open-meteo.com/), met [API-documentatie](https://open-meteo.com/en/docs). Zonuren zijn verwachte uren zon voor de volledige dag, geen zonkanspercentage. Regengegevens: [Buienradar](https://www.buienradar.nl/). Geen API-sleutel nodig. Locatievoorzieningen zijn optioneel; je kunt een stad kiezen.

## Downloaden en installeren

Download [RainBar-NL-v1.2.0-universal.zip](https://github.com/perhorst1234/rain_app/releases/download/v1.2.0/RainBar-NL-v1.2.0-universal.zip) uit [Releases](https://github.com/perhorst1234/rain_app/releases).

1. Gebruik een Mac met **macOS 26 (Tahoe) of nieuwer**. De download bevat zowel Intel (`x86_64`) als Apple Silicon (`arm64`); Rosetta is niet nodig op Apple Silicon.
2. Pak de ZIP uit en sleep **RainBar.app** naar **Programma’s**.
3. Start RainBar. De app verschijnt in de menubalk. Kies een stad en wissel tussen **Regen** en **Weer**.

Deze persoonlijke build is ad-hoc ondertekend en niet door Apple genotariseerd. Als macOS de eerste keer openen blokkeert, kun je na de eerste startpoging via **Systeeminstellingen → Privacy en beveiliging → Open toch** toestemming geven voor deze app. Zie [Apple’s instructies](https://support.apple.com/102445). Een Developer ID-certificaat is niet inbegrepen.

De `SHA256SUMS.txt` bij de release bevat de checksum van de download. De originele broncode en MIT-licentie blijven behouden in deze fork.

## Automatische updates

Installeer versie **1.2.0** eenmalig op iedere Mac. Versie 1.1.0 heeft nog geen updater.
Daarna controleert RainBar ieder uur de nieuwste release van **perhorst1234/rain_app** en downloadt een ondertekende update automatisch. De installatie gebeurt doorgaans bij afsluiten of herstarten van RainBar; als de app blijft draaien, kan Sparkle later een installatie aanbieden. De app moet in een beschrijfbare map staan, bijvoorbeeld Programma’s.

Rechtsklik op het menubalkicoon voor **Zoek naar updates…** en **Automatisch bijwerken**. Deze voorkeur geldt per Mac. GitHub en een internetverbinding moeten bereikbaar zijn.

Een wijziging alleen op je computer verschijnt pas op je laptop nadat een nieuwe release is gepubliceerd. Dit project bouwt en publiceert die automatisch wanneer je een nieuwe versietag pusht:

```sh
git add RainBar Tests Scripts .github README.md
git commit -m "Beschrijf je wijziging"
Scripts/tag-release.sh 1.2.1
```

Het script verhoogt ook het interne buildnummer en pusht branch en tag samen. GitHub Actions test, bouwt voor Intel én Apple Silicon, ondertekent het updatearchief en publiceert ZIP, checksum en `appcast.xml`. Kies bij volgende releases steeds een hoger versienummer. Wacht op een geslaagde workflow voordat je de release als beschikbaar beschouwt.

De geheime Sparkle-sleutel staat in de lokale login-sleutelhanger onder account `rainbar-perhorst1234` en in GitHub Actions-secret `SPARKLE_PRIVATE_KEY`. De publieke sleutel staat in Info.plist. Zowel de feed als het updatearchief worden gecontroleerd; bewaar de privésleutel en roteer hem niet zonder Sparkle’s migratieprocedure. Sparkle-updatehandtekeningen vervangen geen Apple-notarisatie voor een eerste installatie.

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

Checks testen JSON-decoding, ontbrekende uurgegevens, zonuren, dagdelen, Nederlandse zomertijd, grafiekschaal voor motregen, automatische tabkeuze, handmatige tabkeuze, foutafhandeling, locatie-wissels en vertraagde antwoorden. Live checks halen gegevens op van beide weerbronnen. Gebruik `/tmp/rainbar-checks --offline` voor checks zonder externe weerbronnen.

`Scripts/build-release.sh` bouwt en verpakt een universele release en tekent met de lokale Sparkle-sleutel. CI gebruikt `SPARKLE_KEY_FILE` om het afgeschermde Actions-secretbestand te lezen. Een bestaande release-uitvoermap wordt niet overschreven.

## Licentie

MIT; zie LICENSE. Open-Meteo-data valt onder de voorwaarden van Open-Meteo, met bronvermelding in de app.
