# RainBar

A macOS menu bar app that shows rain forecasts for locations in the Netherlands, powered by [Buienradar](https://www.buienradar.nl).

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)

## Features

- **Menu bar status** — shows current rain intensity (mm/h) when raining, upcoming rain time, or "Dry"
- **Rain timeline graph** — 2-hour forecast with smooth area chart, only drawn where rain occurs
- **Interactive hover** — vertical indicator line with dot and glow on rain segments, tooltip with time, mm/h, and description
- **"Now" marker** — red pill indicator showing current time on the graph
- **Location picker** — 8 preset Dutch cities (Amsterdam, Rotterdam, Utrecht, Den Haag, Eindhoven, Groningen, Maastricht, Arnhem)
- **Current location** — uses macOS Location Services to detect your city via reverse geocoding
- **Auto-refresh** — data updates every 5 minutes and on each popover open
- **Liquid glass UI** — native macOS 26 glass effects on buttons, cards, and tooltips

## Data Source

Rain intensity data comes from the Buienradar rain text API (`gpsgadget.buienradar.nl/data/raintext`), which provides 24 five-minute readings covering a 2-hour forecast window. Intensity values (0–255) are converted to mm/h using the formula `10^((value - 109) / 32)`.

## Building

1. Open `RainBar.xcodeproj` in Xcode 26+
2. Build and run (⌘R)

The app requires macOS 26 (Tahoe) or later.

## License

MIT
