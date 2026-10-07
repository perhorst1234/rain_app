import Foundation
import Combine

enum WeatherCondition {
    static func description(_ code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0: return isDay ? "Zonnig" : "Helder"
        case 1: return isDay ? "Vrijwel zonnig" : "Vrijwel helder"
        case 2: return "Halfbewolkt"
        case 3: return "Bewolkt"
        case 45, 48: return "Mistig"
        case 51, 53, 55: return "Motregen"
        case 56, 57, 66, 67: return "IJzel"
        case 61: return "Lichte regen"
        case 63, 65: return "Regen"
        case 71, 73, 75, 77: return "Sneeuw"
        case 80, 81, 82: return "Buien"
        case 85, 86: return "Sneeuwbuien"
        case 95, 96, 99: return "Onweer"
        default: return "Onbekend weer"
        }
    }

    static func symbol(_ code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0, 1: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57, 66, 67: return "cloud.sleet.fill"
        case 61, 63, 65, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "questionmark.circle"
        }
    }
}

struct HourForecast: Identifiable {
    var id: Date { date }
    let date: Date
    let temperature: Double
    let code: Int
    let isDay: Bool
    var feelsLike: Double? = nil
    var rainProbability: Int? = nil
    var rainMM: Double? = nil
    var windKPH: Double? = nil
}

struct DayForecast: Identifiable {
    var id: Date { date }
    let date: Date
    let low: Double
    let high: Double
    let code: Int
    let sunshineHours: Double?
}

enum DayPeriod: String, CaseIterable, Identifiable {
    case all = "Hele dag", morning = "Ochtend", afternoon = "Middag", evening = "Avond"
    var id: String { rawValue }
    func contains(hour: Int) -> Bool {
        switch self {
        case .all: return true
        case .morning: return (6..<12).contains(hour)
        case .afternoon: return (12..<18).contains(hour)
        case .evening: return (18..<24).contains(hour)
        }
    }
}

struct WeatherForecast {
    let observedAt: Date
    let temperature: Double
    let feelsLike: Double
    let code: Int
    let isDay: Bool
    let hours: [HourForecast]
    let days: [DayForecast]

    func upcomingHours(now: Date = Date()) -> [HourForecast] {
        let hourStart = floor(now.timeIntervalSince1970 / 3600) * 3600
        return Array(hours.filter { $0.date.timeIntervalSince1970 >= hourStart }.prefix(12))
    }

    func hours(for day: Date, period: DayPeriod = .all) -> [HourForecast] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return hours.filter {
            calendar.isDate($0.date, inSameDayAs: day) && period.contains(hour: calendar.component(.hour, from: $0.date))
        }
    }

    static func decode(_ data: Data) throws -> WeatherForecast {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let hourly = response.hourly
        let daily = response.daily
        guard hourly.time.count == hourly.temperature_2m.count,
              hourly.time.count == hourly.weather_code.count,
              hourly.time.count == hourly.is_day.count,
              daily.time.count == daily.temperature_2m_min.count,
              daily.time.count == daily.temperature_2m_max.count,
              daily.time.count == daily.weather_code.count,
              daily.time.count == daily.sunshine_duration.count,
              hourly.apparent_temperature.map({ $0.count == hourly.time.count }) ?? true,
              hourly.precipitation_probability.map({ $0.count == hourly.time.count }) ?? true,
              hourly.precipitation.map({ $0.count == hourly.time.count }) ?? true,
              hourly.wind_speed_10m.map({ $0.count == hourly.time.count }) ?? true else {
            throw ForecastError.invalidData
        }
        let hours = hourly.time.indices.compactMap { i -> HourForecast? in
            guard let temperature = hourly.temperature_2m[i],
                  let code = hourly.weather_code[i], let isDay = hourly.is_day[i] else { return nil }
            return HourForecast(date: Date(timeIntervalSince1970: hourly.time[i]),
                                temperature: temperature, code: code, isDay: isDay == 1,
                                feelsLike: hourly.apparent_temperature?[i],
                                rainProbability: hourly.precipitation_probability?[i],
                                rainMM: hourly.precipitation?[i], windKPH: hourly.wind_speed_10m?[i])
        }
        let days = daily.time.indices.compactMap { i -> DayForecast? in
            guard let low = daily.temperature_2m_min[i], let high = daily.temperature_2m_max[i],
                  let code = daily.weather_code[i] else { return nil }
            return DayForecast(date: Date(timeIntervalSince1970: daily.time[i]), low: low,
                               high: high, code: code, sunshineHours: daily.sunshine_duration[i].map { $0 / 3600 })
        }
        guard !hours.isEmpty, !days.isEmpty else { throw ForecastError.invalidData }
        return WeatherForecast(observedAt: Date(timeIntervalSince1970: response.current.time),
                               temperature: response.current.temperature_2m,
                               feelsLike: response.current.apparent_temperature,
                               code: response.current.weather_code, isDay: response.current.is_day == 1,
                               hours: hours, days: days)
    }

    private struct Response: Decodable {
        let current: Current
        let hourly: Hourly
        let daily: Daily
        struct Current: Decodable {
            let time: Double
            let temperature_2m: Double
            let apparent_temperature: Double
            let weather_code: Int
            let is_day: Int
        }
        struct Hourly: Decodable {
            let time: [Double]
            let temperature_2m: [Double?]
            let weather_code: [Int?]
            let is_day: [Int?]
            let apparent_temperature: [Double?]?
            let precipitation_probability: [Int?]?
            let precipitation: [Double?]?
            let wind_speed_10m: [Double?]?
        }
        struct Daily: Decodable {
            let time: [Double]
            let temperature_2m_min: [Double?]
            let temperature_2m_max: [Double?]
            let weather_code: [Int?]
            let sunshine_duration: [Double?]
        }
    }
}

enum ForecastError: LocalizedError {
    case invalidData
    case http(Int)
    var errorDescription: String? {
        switch self {
        case .invalidData: return "Weerbron gaf geen bruikbare gegevens terug."
        case .http(let status): return "Weerbron tijdelijk niet bereikbaar (\(status))."
        }
    }
}

@MainActor
final class WeatherService: ObservableObject {
    @Published private(set) var forecast: WeatherForecast?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    private var requestID = UUID()
    @Published private(set) var coordinates: String?

    func prepare(for location: LocationConfig) {
        let key = "\(location.latitude),\(location.longitude)"
        guard coordinates != key else { return }
        coordinates = key
        requestID = UUID()
        forecast = nil
        lastUpdated = nil
        errorMessage = nil
        isLoading = false
    }

    func fetch(for location: LocationConfig, session: URLSession = .shared) async {
        prepare(for: location)
        let id = UUID()
        requestID = id
        isLoading = true
        errorMessage = nil
        defer { if requestID == id { isLoading = false } }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            URLQueryItem(name: "hourly", value: "temperature_2m,apparent_temperature,weather_code,is_day,precipitation_probability,precipitation,wind_speed_10m"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunshine_duration"),
            URLQueryItem(name: "timezone", value: "Europe/Amsterdam"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "5")
        ]
        guard let url = components.url else { errorMessage = "Ongeldig weeradres."; return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw ForecastError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
            }
            let result = try WeatherForecast.decode(data)
            try Task.checkCancellation()
            guard requestID == id else { return }
            forecast = result
            lastUpdated = Date()
        } catch {
            guard requestID == id, !Task.isCancelled else { return }
            errorMessage = "Weer ophalen mislukt. Controleer je verbinding en probeer opnieuw."
        }
    }
}
