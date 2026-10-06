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
