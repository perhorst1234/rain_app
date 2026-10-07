import SwiftUI
import Charts

struct RainPopoverView: View {
    @ObservedObject var rainService: RainService
    @ObservedObject var weatherService: WeatherService
    let refresh: () -> Void
    @ObservedObject var presentation: PopoverPresentation
    let onSizeChange: (CGSize) -> Void
    @StateObject private var locationManager = LocationManager()
    @State private var hoveredIndex: Int?
    @State private var showLocationPicker = false

    var body: some View {
        VStack(spacing: 12) {
            headerView
            if presentation.selectedTab == .weather {
                WeatherView(service: weatherService, refresh: refresh, presentation: presentation)
            } else if rainService.isLoading && rainService.readings.isEmpty {
                loadingView
            } else if let error = rainService.errorMessage, rainService.readings.isEmpty {
                errorView(error)
            } else {
                rainContentView
            }
        }
        .padding(12)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { geometry in
            Color.clear.preference(key: PopoverSizeKey.self, value: geometry.size)
        })
        .onPreferenceChange(PopoverSizeKey.self, perform: onSizeChange)
        .onChange(of: presentation.openingID) { _, _ in
            showLocationPicker = false
            hoveredIndex = nil
        }
        .environment(\.locale, Locale(identifier: "nl_NL"))
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            guard let location = newLocation else { return }
            let name = locationManager.cityName ?? "Huidige locatie"
            rainService.updateFromCurrentLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                cityName: name
            )
            refresh()
            showLocationPicker = false
        }
        .onChange(of: locationManager.cityName) { _, newName in
            guard let name = newName, rainService.usesCurrentLocation else { return }
            rainService.location = LocationConfig(
                name: name,
                latitude: rainService.location.latitude,
                longitude: rainService.location.longitude
            )
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 6) {
            Button(action: { showLocationPicker.toggle() }) {
                HStack(spacing: 5) {
                    Image(systemName: rainService.usesCurrentLocation ? "location.fill" : "mappin.circle.fill")
                        .font(.system(size: 11))
                    Text(rainService.location.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 105, alignment: .leading)
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())
            .popover(isPresented: $showLocationPicker) {
                locationPickerView
            }

            Picker("Vooruitzicht", selection: Binding(
                get: { presentation.selectedTab }, set: { presentation.select($0) }
            )) {
                Text("Regen").tag(ForecastTab.rain)
                Text("Weer").tag(ForecastTab.weather)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 118)
            Spacer(minLength: 0)

            if rainService.isLoading || weatherService.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            }

            if let lastUpdated = presentation.selectedTab == .rain ? rainService.lastUpdated : weatherService.lastUpdated {
                Text(lastUpdated, formatter: timeFormatter)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Button(action: {
                refresh()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())
            .help("Verversen")
            .accessibilityLabel("Verversen")

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())
            .help("RainBar afsluiten")
            .accessibilityLabel("RainBar afsluiten")
        }
    }

    // MARK: - Location Picker

    private var locationPickerView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                locationManager.requestLocation()
            }) {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                    Text("Huidige locatie")
                        .font(.system(size: 12))
                    Spacer()
                    if locationManager.isLocating {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.6)
                    } else if rainService.usesCurrentLocation {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if let error = locationManager.error {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 2)
            }

            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            ForEach(LocationConfig.allCities, id: \.name) { city in
                Button(action: {
                    rainService.selectCity(city)
                    showLocationPicker = false
                    refresh()
                }) {
                    HStack {
                        Text(city.name)
                            .font(.system(size: 12))
                        Spacer()
                        if !rainService.usesCurrentLocation && city.name == rainService.location.name {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 200)

    }

    // MARK: - Status Summary

    private var statusSummaryView: some View {
        HStack(spacing: 8) {
            if rainService.hasRainComing {
                Image(systemName: "cloud.rain.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .font(.system(size: 18))

                if let firstReading = rainService.readings.first, firstReading.mmPerHour > 0 {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Het regent nu")
                            .font(.system(size: 13, weight: .semibold))
                        if let stops = rainService.rainStopsTime {
                            Text("Droog rond \(stops)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let nextRain = rainService.nextRainTime {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Regen verwacht")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Vanaf \(nextRain)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "cloud")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Geen regen verwacht")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Komende 2 uur")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    // MARK: - Rain Content

    private var rainContentView: some View {
        VStack(spacing: 10) {
            statusSummaryView
            graphSection
            tooltipView
            if let error = rainService.errorMessage {
                Text(error).font(.system(size: 10)).foregroundStyle(.orange)
            }

        }

    }

    private var graphSection: some View {
        let readings = rainService.readings
        let upper = RainChartScale.upperBound(for: readings)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Regen · mm/u").font(.system(size: 10)).foregroundStyle(.secondary)
            Chart {
                ForEach(Array(readings.enumerated()), id: \.offset) { index, reading in
                    AreaMark(x: .value("Tijd", index), y: .value("Regen", reading.mmPerHour))
                        .foregroundStyle(LinearGradient(colors: [.cyan.opacity(0.5), .blue.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Tijd", index), y: .value("Regen", reading.mmPerHour))
                        .foregroundStyle(.cyan).lineStyle(StrokeStyle(lineWidth: 2))
                    if reading.mmPerHour > 0 {
                        PointMark(x: .value("Tijd", index), y: .value("Regen", reading.mmPerHour))
                            .foregroundStyle(.cyan).symbolSize(18)
                    }
                }
                if let index = findNowIndex(readings: readings) {
                    RuleMark(x: .value("Nu", index)).foregroundStyle(.red.opacity(0.55))
                        .annotation(position: .top, alignment: .leading) {
                            Text("NU").font(.system(size: 7, weight: .bold)).foregroundStyle(.red)
                        }
                }
                if let index = hoveredIndex, readings.indices.contains(index) {
                    RuleMark(x: .value("Geselecteerd", index)).foregroundStyle(.secondary.opacity(0.4))
                    PointMark(x: .value("Tijd", index), y: .value("Regen", readings[index].mmPerHour))
                        .foregroundStyle(.white).symbolSize(40)
                }
            }
            .chartXScale(domain: 0...max(readings.count - 1, 1), range: .plotDimension(padding: 5))
            .chartYScale(domain: 0...upper)
            .chartXAxis {
                AxisMarks(values: timeTickIndices(count: readings.count)) { value in
                    AxisValueLabel(anchor: value.index == 0 ? .topLeading : value.index == value.count - 1 ? .topTrailing : .top, collisionResolution: .disabled) {
                        if let index = value.as(Int.self), readings.indices.contains(index) {
                            Text(readings[index].time).font(.system(size: 9, design: .monospaced))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, upper / 2, upper]) { value in
                    AxisGridLine().foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let mm = value.as(Double.self) {
                            Text(mm.formatted(.number.locale(Locale(identifier: "nl_NL")).precision(.fractionLength(0...2))))
                                .font(.system(size: 9, design: .monospaced))
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Color.clear.contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let point):
                                guard let plot = proxy.plotFrame else { return }
                                let frame = geometry[plot]
                                guard frame.contains(point), let value: Double = proxy.value(atX: point.x - frame.minX) else {
                                    hoveredIndex = nil; return
                                }
                                hoveredIndex = min(max(Int(value.rounded()), 0), max(readings.count - 1, 0))
                            case .ended: hoveredIndex = nil
                            }
                        }
                }
            }
            .overlay {
                if !rainService.hasRainComing {
                    Text("Geen regen in de komende 2 uur").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .frame(height: 165)
            .accessibilityLabel("Regenverwachting per vijf minuten, schaal nul tot \(upper) millimeter per uur")
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    private func timeTickIndices(count: Int) -> [Int] {
        guard count > 1 else { return [] }
        return Array(Set([0, (count - 1) / 4, (count - 1) / 2, 3 * (count - 1) / 4, count - 1])).sorted()
    }

    // MARK: - Tooltip

    private var tooltipView: some View {
        Group {
            if let index = hoveredIndex, index < rainService.readings.count {
                let reading = rainService.readings[index]
                HStack(spacing: 10) {
                    Text(reading.time)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    Divider().frame(height: 14)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(dotColor(for: reading))
                            .frame(width: 6, height: 6)
                        Text("\(reading.mmPerHour.formatted(.number.locale(Locale(identifier: "nl_NL")).precision(.fractionLength(1)))) mm/u")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    Text(reading.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(in: .rect(cornerRadius: 10))
            } else {
                HStack {
                    Text("Beweeg over de grafiek voor details")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("Buienradar.nl")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(height: 30)
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Regen ophalen…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(height: 150)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Opnieuw proberen") {
                refresh()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(height: 150)
    }

    // MARK: - Helpers

    private func dotColor(for reading: RainReading) -> Color {
        if reading.mmPerHour == 0 { return .green }
        if reading.mmPerHour < 1.0 { return .cyan }
        if reading.mmPerHour < 5.0 { return .blue }
        if reading.mmPerHour < 10.0 { return Color(red: 0.2, green: 0.2, blue: 0.9) }
        return Color(red: 0.5, green: 0.1, blue: 0.8)
    }

    private func findNowIndex(readings: [RainReading]) -> Int? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        let now = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        for (index, reading) in readings.enumerated() {
            let parts = reading.time.split(separator: ":")
            guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { continue }
            let minutesAhead = (hour * 60 + minute - now + 1440) % 1440
            if minutesAhead <= 120 { return index }
        }
        return nil
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "nl_NL")
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f
    }
}

private struct PopoverSizeKey: PreferenceKey {
    static var defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}
