# Releasecontrole 1.2.1

Controle uitgevoerd op 7 oktober 2026. Deze versie herstelt de schaal voor lichte regen, plaatst tabs in de bovenbalk, laat de vensterhoogte aansluiten op de inhoud, kiest de openingstab op basis van regen en voegt klikbare dagdetails en Sparkle-updates toe.

CodeRabbit raised 0 issues in de review van appwijzigingen, tests, scripts, package-lock en releaseworkflow. Na de review zijn de laatste aslabels expliciet zichtbaar gemaakt, is automatische tabkeuze beperkt tot de eerste verse voorspelling per opening, is menuvalidatie expliciet ingesteld en is de lipo-argumentvolgorde in het release-script gecorrigeerd. De laatste universele build en 32 offline functionele checks zijn geslaagd. Alle 35 functionele checks zijn geslaagd, inclusief drie live integratiechecks. Native NSHostingController bevestigt hoogtes van 375 px (Regen) en 518 px (Weer), beide 500 px breed.

De tweede CodeRabbit-review gaf twee minor opmerkingen: de nog voorlopige validatietekst bijwerken zodra controles klaar zijn, en de volledige dagrij klikbaar maken met `contentShape(Rectangle())`. De dagrij is aangepast; de validatietekst is bijgewerkt met de uitgevoerde controles.

## Controles

- Functionele checks: gegevensdecoding, optionele uurgegevens, afwijzing van verkeerde arraylengtes, zonuren, nachtweergave, dag-/avondfilter, Nederlandse zomertijd, lichte en zware regen, automatische openingstab, behoud van handmatige keuze, locatie-wissels en vertraagde antwoorden.
- Live integratiechecks voor Buienradar en Open-Meteo, inclusief regen, wind en gevoelstemperatuur per uur.
- Universele Release-build voor x86_64 en arm64. Sparkle 2.10.0 als vastgepinde package; framework en helpers in de app.
- Indeling gecontroleerd met afzonderlijke SwiftUI-renders van de compacte regen- en weerinhoud en dagdetails. Native glas, segmented controls en scrollinhoud zijn daarin niet volledig renderbaar; dit is geen volledige native UI-test.
- Debuggegevens uit de eigen executable verwijderd en app opnieuw ad-hoc ondertekend. Bundlehandtekeningen en beide architecturen gecontroleerd.
- Feed en archief ondertekend via Ed25519; beide verplicht gecontroleerd door de updater. Privésleutel in login-sleutelhanger en Actions-secret, buiten broncode.
- [GitHub Actions-run 37667859721](https://github.com/perhorst1234/rain_app/actions/runs/37667859721) geslaagd op Apple Silicon (`macos-26`, Xcode 26.6): 32 offline functionele checks, universele build, handtekeningen en publicatie.
- Gepubliceerde ZIP en feed opnieuw gedownload en checksums gecontroleerd; CryptoKit accepteert beide met de publieke sleutel uit de app en wijst gewijzigde versies af.
- Sparkle zelf gestart tegen een lokale build 3: automatische controles en downloads actief, interval 3600 seconden. De echte ondertekende GitHub-feed werd geaccepteerd en update 1.2.1 (build 4) herkend. De update-installatie op een tweede Mac is niet rechtstreeks getest.
- Gepubliceerde versie 1.2.1 geïnstalleerd en gestart op deze Intel-Hackintosh. Oude app bewaard buiten Programma’s. Native app niet op Apple Silicon-hardware geopend; modelchecks daar wel via CI uitgevoerd.
- SHA-256 ZIP: `3c2c55497bc81538233118250856edb10e28ec45e0beabf0a83aa50675f9743e`.

De eerste installatie is niet door Apple genotariseerd. Versie 1.1.0 moet eenmalig handmatig worden vervangen; die versie bevat nog geen updater. Lokaal gewijzigde broncode wordt pas een update op andere Macs nadat een nieuwe GitHub-release is gepubliceerd.

---

# Releasecontrole 1.1.0

De fork voegt Nederlandse bediening, twee tabs voor regen en weer, temperatuur in de menubalk en een download voor Intel en Apple Silicon toe. Controle uitgevoerd op 6 oktober 2026.

CodeRabbit raised 2 issues.

## ℹ️ Minor

- `Tests/ForecastChecks.swift:106`: de live Buienradar-check verwacht precies 24 metingen, terwijl de parser minimaal twee metingen accepteert. Voorgestelde wijziging: accepteer `readings.count >= 2`, met behoud van de foutcontrole. Geen wijziging: deze live integratiecheck controleert bewust de normale 24-metingenrespons van de bron; de tolerante parser is een apart contract.
- `RainBar/RainBarApp.swift:45–48`: de review suggereert dat een menubalkupdate op `objectWillChange` oude waarden kan lezen. Voorgestelde wijziging: expliciet naar de volgende main-queuecyclus uitstellen of gepubliceerde waarden gebruiken. Geen wijziging: de bestaande `.receive(on: RunLoop.main)` stelt de callback al uit. Een aparte Combine-check met beide publishers bevestigde dat de callback de nieuwe waarden leest.

## Overige controles

- Negentien functionele checks geslaagd: JSON-decoding, zonuren, dag/nacht, Nederlandse regenstatus, foutafhandeling, locatie-wissels, vertraagde antwoorden en live requests naar beide weerbronnen.
- Universele Release-build geslaagd; executable bevat `x86_64` en `arm64`.
- Codehandtekening gecontroleerd vóór en na het uitpakken van de release-ZIP.
- Debuggegevens met lokale bouwpaden verwijderd; app daarna opnieuw ad-hoc ondertekend.
- Broncode gecontroleerd op tokens, privésleutels en lokale gebruikerspaden. Xcode-gebruikersstatus uit de fork verwijderd.
- Intel-app uitgevoerd op deze Hackintosh. Apple Silicon-build niet op Apple Silicon-hardware uitgevoerd.

De app is niet door Apple genotariseerd. `SHA256SUMS.txt` bij de release bevat de checksum van de universele download.
