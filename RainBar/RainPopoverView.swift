import SwiftUI

struct RainPopoverView: View {
    @ObservedObject var rainService: RainService
    @StateObject private var locationManager = LocationManager()
    @State private var hoveredIndex: Int?
    @State private var showLocationPicker = false

    var body: some View {
        VStack(spacing: 12) {
            headerView
            if rainService.isLoading && rainService.readings.isEmpty {
                loadingView
            } else if let error = rainService.errorMessage, rainService.readings.isEmpty {
                errorView(error)
            } else {
                rainContentView
            }
        }
        .padding(16)
        .frame(width: 440, height: 360)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 10) {
            Button(action: { showLocationPicker.toggle() }) {
                HStack(spacing: 5) {
                    Image(systemName: rainService.usesCurrentLocation ? "location.fill" : "mappin.circle.fill")
                        .font(.system(size: 11))
                    Text(rainService.location.name)
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

            Spacer()

            if rainService.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            }

            if let lastUpdated = rainService.lastUpdated {
                Text(lastUpdated, formatter: timeFormatter)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Button(action: {
                Task { await rainService.fetchRainData() }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())
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
                    Text("Current Location")
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
                    Task { await rainService.fetchRainData() }
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
        .onChange(of: locationManager.currentLocation) { newLocation in
            guard let location = newLocation else { return }
            let name = locationManager.cityName ?? "Current Location"
            rainService.updateFromCurrentLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                cityName: name
            )
            Task { await rainService.fetchRainData() }
            showLocationPicker = false
        }
        .onChange(of: locationManager.cityName) { newName in
            guard let name = newName, rainService.usesCurrentLocation else { return }
            rainService.location = LocationConfig(
                name: name,
                latitude: rainService.location.latitude,
                longitude: rainService.location.longitude
            )
        }
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
                        Text("Raining now")
                            .font(.system(size: 13, weight: .semibold))
                        if let stops = rainService.rainStopsTime {
                            Text("Stops around \(stops)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let nextRain = rainService.nextRainTime {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rain expected")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Starting at \(nextRain)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "sun.max.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 1) {
                    Text("No rain expected")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Next 2 hours")
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
        }
    }

    private var graphSection: some View {
        VStack(spacing: 0) {
            rainGraphView
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 4)
            timeLabelsView
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    // MARK: - Rain Graph

    private var rainGraphView: some View {
        GeometryReader { geometry in
            let readings = rainService.readings
            if readings.isEmpty {
                EmptyView()
            } else {
                let graphWidth = geometry.size.width
                let graphHeight = geometry.size.height
                let hasAnyRain = readings.contains { $0.mmPerHour > 0 }
                let maxMM = max(readings.map(\.mmPerHour).max() ?? 1, 2.0)
                let stepX = graphWidth / CGFloat(readings.count - 1)

                ZStack(alignment: .topLeading) {
                    gridLines(graphHeight: graphHeight)

                    if hasAnyRain {
                        areaFill(readings: readings, maxMM: maxMM, stepX: stepX, graphHeight: graphHeight, graphWidth: graphWidth)
                        strokeLine(readings: readings, maxMM: maxMM, stepX: stepX, graphHeight: graphHeight)
                        hoverDots(readings: readings, maxMM: maxMM, stepX: stepX, graphHeight: graphHeight)
                    } else {
                        Text("No rain in the next 2 hours")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    nowIndicator(readings: readings, stepX: stepX, graphHeight: graphHeight)
                    hoverOverlay(readings: readings, stepX: stepX, graphWidth: graphWidth, graphHeight: graphHeight)
                }
            }
        }
        .frame(height: 130)
    }

    private func gridLines(graphHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                Spacer()
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 0.5)
            }
        }
        .frame(height: graphHeight)
    }

    private func areaFill(readings: [RainReading], maxMM: Double, stepX: CGFloat, graphHeight: CGFloat, graphWidth: CGFloat) -> some View {
        Path { path in
            var inRainSegment = false
            for (i, reading) in readings.enumerated() {
                let x = CGFloat(i) * stepX
                let hasRain = reading.mmPerHour > 0
                let prevHasRain = i > 0 && readings[i - 1].mmPerHour > 0

                if hasRain || prevHasRain {
                    let y = graphHeight - (CGFloat(reading.mmPerHour) / CGFloat(maxMM)) * graphHeight
                    if !inRainSegment {
                        path.move(to: CGPoint(x: x, y: graphHeight))
                        path.addLine(to: CGPoint(x: x, y: y))
                        inRainSegment = true
                    } else {
                        let prevX = CGFloat(i - 1) * stepX
                        let prevY = graphHeight - (CGFloat(readings[i - 1].mmPerHour) / CGFloat(maxMM)) * graphHeight
                        let midX = (prevX + x) / 2
                        path.addCurve(
                            to: CGPoint(x: x, y: y),
                            control1: CGPoint(x: midX, y: prevY),
                            control2: CGPoint(x: midX, y: y)
                        )
                    }

                    if !hasRain {
                        path.addLine(to: CGPoint(x: x, y: graphHeight))
                        path.closeSubpath()
                        inRainSegment = false
                    }
                }
            }
            if inRainSegment {
                let lastX = CGFloat(readings.count - 1) * stepX
                path.addLine(to: CGPoint(x: lastX, y: graphHeight))
                path.closeSubpath()
            }
        }
        .fill(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.4),
                    Color.cyan.opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func strokeLine(readings: [RainReading], maxMM: Double, stepX: CGFloat, graphHeight: CGFloat) -> some View {
        Path { path in
            var inRainSegment = false
            for (i, reading) in readings.enumerated() {
                let x = CGFloat(i) * stepX
                let hasRain = reading.mmPerHour > 0
                let prevHasRain = i > 0 && readings[i - 1].mmPerHour > 0

                if hasRain || prevHasRain {
                    let y = graphHeight - (CGFloat(reading.mmPerHour) / CGFloat(maxMM)) * graphHeight
                    if !inRainSegment {
                        path.move(to: CGPoint(x: x, y: y))
                        inRainSegment = true
                    } else {
                        let prevX = CGFloat(i - 1) * stepX
                        let prevY = graphHeight - (CGFloat(readings[i - 1].mmPerHour) / CGFloat(maxMM)) * graphHeight
                        let midX = (prevX + x) / 2
                        path.addCurve(
                            to: CGPoint(x: x, y: y),
                            control1: CGPoint(x: midX, y: prevY),
                            control2: CGPoint(x: midX, y: y)
                        )
                    }

                    if !hasRain {
                        inRainSegment = false
                    }
                }
            }
        }
        .stroke(Color.blue, lineWidth: 2)
    }

    private func hoverDots(readings: [RainReading], maxMM: Double, stepX: CGFloat, graphHeight: CGFloat) -> some View {
        ForEach(Array(readings.enumerated()), id: \.offset) { index, reading in
            if hoveredIndex == index {
                let x = CGFloat(index) * stepX

                Rectangle()
                    .fill(Color.white.opacity(reading.mmPerHour > 0 ? 0.3 : 0.15))
                    .frame(width: 1, height: graphHeight)
                    .position(x: x, y: graphHeight / 2)

                if reading.mmPerHour > 0 {
                    let y = graphHeight - (CGFloat(reading.mmPerHour) / CGFloat(maxMM)) * graphHeight

                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 20, height: 20)
                        .position(x: x, y: y)

                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: .blue.opacity(0.6), radius: 5)
                        .position(x: x, y: y)
                }
            }
        }
    }

    private func nowIndicator(readings: [RainReading], stepX: CGFloat, graphHeight: CGFloat) -> some View {
        Group {
            if let nowIdx = findNowIndex(readings: readings) {
                let x = CGFloat(nowIdx) * stepX
                VStack(spacing: 2) {
                    Text("NOW")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.8), in: Capsule())
                    Rectangle()
                        .fill(Color.red.opacity(0.4))
                        .frame(width: 1, height: graphHeight - 14)
                }
                .position(x: x, y: graphHeight / 2)
            }
        }
    }

    private func hoverOverlay(readings: [RainReading], stepX: CGFloat, graphWidth: CGFloat, graphHeight: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: graphWidth, height: graphHeight)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let index = Int(round(location.x / stepX))
                    hoveredIndex = max(0, min(index, readings.count - 1))
                case .ended:
                    hoveredIndex = nil
                }
            }
    }

    // MARK: - Time Labels

    private var timeLabelsView: some View {
        let readings = rainService.readings
        guard !readings.isEmpty else { return AnyView(EmptyView()) }

        let labelInterval = readings.count <= 12 ? 3 : 6

        return AnyView(
            GeometryReader { geo in
                let stepX = geo.size.width / CGFloat(readings.count - 1)
                ZStack(alignment: .leading) {
                    ForEach(Array(readings.enumerated()), id: \.offset) { index, reading in
                        if index % labelInterval == 0 {
                            Text(reading.time)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .position(x: CGFloat(index) * stepX, y: 8)
                        }
                    }
                }
            }
            .frame(height: 18)
        )
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
                        Text(String(format: "%.1f mm/h", reading.mmPerHour))
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
                    Text("Hover graph for details")
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
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text("Loading rain data...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await rainService.fetchRainData() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func dotColor(for reading: RainReading) -> Color {
        if reading.mmPerHour == 0 { return .green }
        if reading.mmPerHour < 1.0 { return .cyan }
        if reading.mmPerHour < 5.0 { return .blue }
        if reading.mmPerHour < 10.0 { return Color(red: 0.2, green: 0.2, blue: 0.9) }
        return Color(red: 0.5, green: 0.1, blue: 0.8)
    }

    private func scaleSteps(for maxMM: Double) -> [Double] {
        if maxMM <= 1 { return [0.2, 0.5, 1.0] }
        if maxMM <= 2 { return [0.5, 1.0, 2.0] }
        if maxMM <= 5 { return [1, 2, 5] }
        if maxMM <= 10 { return [2, 5, 10] }
        if maxMM <= 25 { return [5, 10, 25] }
        return [10, 25, 50]
    }

    private func findNowIndex(readings: [RainReading]) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let nowString = formatter.string(from: Date())
        for (index, reading) in readings.enumerated() {
            if reading.time >= nowString {
                return index
            }
        }
        return nil
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }
}
