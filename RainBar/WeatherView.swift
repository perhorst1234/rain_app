import SwiftUI
import Charts

struct WeatherView: View {
    @ObservedObject var service: WeatherService
    let refresh: () -> Void

    var body: some View {
        Group {
            if let forecast = service.forecast {
                VStack(spacing: 10) {
                    currentCard(forecast)
                    hourlyCard(forecast)
                    dailyCard(forecast)
                    HStack {
                        if let error = service.errorMessage {
                            Text(error).foregroundStyle(.orange)
                        } else if let updated = service.lastUpdated {
                            Text("Bijgewerkt om \(updated.formatted(.dateTime.hour().minute().locale(Locale(identifier: "nl_NL"))))")
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Link("Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 9))
                    .padding(.horizontal, 4)
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    if let error = service.errorMessage {
                        Image(systemName: "cloud.slash").font(.system(size: 28)).foregroundStyle(.orange)
                        Text(error).font(.system(size: 12)).multilineTextAlignment(.center)
                        Button("Opnieuw proberen", action: refresh).buttonStyle(.borderedProminent)
                    } else {
                        ProgressView()
                        Text("Weer ophalen…").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func currentCard(_ forecast: WeatherForecast) -> some View {
        HStack(spacing: 12) {
            Image(systemName: WeatherCondition.symbol(forecast.code, isDay: forecast.isDay))
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 30))
                .foregroundStyle(conditionColor(forecast.code, isDay: forecast.isDay))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(WeatherCondition.description(forecast.code, isDay: forecast.isDay))
                    .font(.system(size: 13, weight: .semibold))
                Text("Voelt als \(degrees(forecast.feelsLike))")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(degrees(forecast.temperature)).font(.system(size: 34, weight: .light, design: .rounded))
                Text("Nu · °C").font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    private func hourlyCard(_ forecast: WeatherForecast) -> some View {
        let hours = forecast.upcomingHours()
        let low = (hours.map(\.temperature).min() ?? 0) - 2
        let high = (hours.map(\.temperature).max() ?? 20) + 2
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Komende 12 uur").font(.system(size: 11, weight: .semibold))
                Spacer()
                Label("Temperatuur", systemImage: "thermometer.medium")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            if hours.count > 1 {
                Chart(hours) { hour in
                    AreaMark(x: .value("Tijd", hour.date), yStart: .value("Basis", low), yEnd: .value("Temperatuur", hour.temperature))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.28), .orange.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Tijd", hour.date), y: .value("Temperatuur", hour.temperature))
                        .interpolationMethod(.monotone).lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(.orange)
                }
                .chartYScale(domain: low...high)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(.quaternary)
                        AxisValueLabel {
                            if let temperature = value.as(Double.self) {
                                Text(degrees(temperature)).font(.system(size: 9))
                            }
                        }
                    }
                }
                .frame(height: 58)
                .accessibilityLabel("Temperatuurverloop voor de komende twaalf uur")
            }
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(hours) { hour in
                        VStack(spacing: 4) {
                            Text(hour.date, formatter: hourFormatter).font(.system(size: 9)).foregroundStyle(.secondary)
                            Image(systemName: WeatherCondition.symbol(hour.code, isDay: hour.isDay))
                                .symbolRenderingMode(.hierarchical).foregroundStyle(conditionColor(hour.code, isDay: hour.isDay))
                                .font(.system(size: 13))
                            Text(degrees(hour.temperature)).font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .frame(width: 36)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(hour.date.formatted(.dateTime.hour().minute().locale(Locale(identifier: "nl_NL")))), \(degrees(hour.temperature)), \(WeatherCondition.description(hour.code, isDay: hour.isDay))")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    private func dailyCard(_ forecast: WeatherForecast) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Komende dagen").font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("min / max").frame(width: 76, alignment: .trailing)
                Text("Zonuren").frame(width: 62, alignment: .trailing)
            }
            .font(.system(size: 9)).foregroundStyle(.secondary).padding(.bottom, 7)
            ForEach(forecast.days) { day in
                HStack(spacing: 8) {
                    Text(dayName(day.date)).font(.system(size: 11, weight: .medium)).frame(width: 54, alignment: .leading)
                    Image(systemName: WeatherCondition.symbol(day.code))
                        .symbolRenderingMode(.hierarchical).foregroundStyle(conditionColor(day.code)).frame(width: 20)
                    Text(WeatherCondition.description(day.code)).font(.system(size: 10)).foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    HStack(spacing: 5) {
                        Text(degrees(day.low)).foregroundStyle(.secondary)
                        Text(degrees(day.high)).fontWeight(.semibold)
                    }
                    .font(.system(size: 11, design: .rounded)).frame(width: 76, alignment: .trailing)
                    Text(day.sunshineHours.map { "\($0.formatted(.number.locale(Locale(identifier: "nl_NL")).precision(.fractionLength(1)))) u" } ?? "—")
                        .font(.system(size: 10, design: .rounded)).frame(width: 62, alignment: .trailing)
                }
                .frame(height: 25)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    private func degrees(_ value: Double) -> String {
        "\(value.formatted(.number.locale(Locale(identifier: "nl_NL")).precision(.fractionLength(0))))°"
    }

    private func conditionColor(_ code: Int, isDay: Bool = true) -> Color {
        switch code {
        case 0, 1, 2: return isDay ? .orange : .indigo
        case 3, 45, 48: return .gray
        case 71, 73, 75, 77, 85, 86: return .cyan
        case 95, 96, 99: return .purple
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return .blue
        default: return .gray
        }
    }

    private func dayName(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        if calendar.isDate(date, inSameDayAs: Date()) { return "Vandaag" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()), calendar.isDate(date, inSameDayAs: tomorrow) { return "Morgen" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }

    private var hourFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}
