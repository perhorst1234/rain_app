import Foundation
import Combine

struct RainReading: Identifiable {
    let id = UUID()
    let time: String
    let intensity: Double

    var mmPerHour: Double {
        guard intensity > 0 else { return 0 }
        return pow(10, (intensity - 109) / 32)
    }

    var description: String {
        if mmPerHour == 0 { return "Droog" }
        if mmPerHour < 0.5 { return "Motregen" }
        if mmPerHour < 2.0 { return "Lichte regen" }
        if mmPerHour < 5.0 { return "Matige regen" }
        if mmPerHour < 10.0 { return "Zware regen" }
        return "Zeer zware regen"
    }
}

struct LocationConfig {
    var name: String
    var latitude: Double
    var longitude: Double

    static let amsterdam = LocationConfig(name: "Amsterdam", latitude: 52.3676, longitude: 4.9041)
    static let rotterdam = LocationConfig(name: "Rotterdam", latitude: 51.9225, longitude: 4.4792)
    static let utrecht = LocationConfig(name: "Utrecht", latitude: 52.0907, longitude: 5.1214)
    static let denHaag = LocationConfig(name: "Den Haag", latitude: 52.0705, longitude: 4.3007)
    static let eindhoven = LocationConfig(name: "Eindhoven", latitude: 51.4416, longitude: 5.4697)
    static let groningen = LocationConfig(name: "Groningen", latitude: 53.2194, longitude: 6.5665)
    static let maastricht = LocationConfig(name: "Maastricht", latitude: 50.8514, longitude: 5.6910)
    static let arnhem = LocationConfig(name: "Arnhem", latitude: 51.9851, longitude: 5.8987)

    static let allCities: [LocationConfig] = [
        .amsterdam, .rotterdam, .utrecht, .denHaag,
        .eindhoven, .groningen, .maastricht, .arnhem
    ]
}

@MainActor
class RainService: ObservableObject {
    private var requestID = UUID()
    @Published var readings: [RainReading] = []
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var usesCurrentLocation = false {
        didSet {
            UserDefaults.standard.set(usesCurrentLocation, forKey: "usesCurrentLocation")
        }
    }
    @Published var location: LocationConfig {
        didSet {
            if oldValue.latitude != location.latitude || oldValue.longitude != location.longitude {
                requestID = UUID()
                readings = []
                lastUpdated = nil
                errorMessage = nil
                isLoading = false
            }
            UserDefaults.standard.set(location.name, forKey: "selectedCity")
            UserDefaults.standard.set(location.latitude, forKey: "selectedLat")
            UserDefaults.standard.set(location.longitude, forKey: "selectedLon")
        }
    }

    var hasRainComing: Bool {
        readings.contains { $0.mmPerHour > 0 }
    }

    var isRainingNow: Bool {
        guard let first = readings.first else { return false }
        return first.mmPerHour > 0
    }

    var currentRainMM: Double {
        readings.first?.mmPerHour ?? 0
    }

    var nextRainTime: String? {
        guard let first = readings.first(where: { $0.mmPerHour > 0 }) else { return nil }
        return first.time
    }

    var rainStopsTime: String? {
        guard hasRainComing else { return nil }
        guard let firstRain = readings.firstIndex(where: { $0.mmPerHour > 0 }) else { return nil }
        let afterRain = readings[firstRain...].first(where: { $0.mmPerHour == 0 })
        return afterRain?.time
    }

    var menuBarText: String {
        if readings.isEmpty { return errorMessage == nil ? "…" : "Geen data" }
        if isRainingNow {
            let mm = currentRainMM
            if mm < 0.1 { return "0,1 mm/u" }
            return "\(mm.formatted(.number.locale(Locale(identifier: "nl_NL")).precision(.fractionLength(1)))) mm/u"
        }
        if let nextRain = nextRainTime {
            return "Regen \(nextRain)"
        }
        return "Droog"
    }

    init() {
        let savedUsesCurrentLocation = UserDefaults.standard.bool(forKey: "usesCurrentLocation")
        self.usesCurrentLocation = savedUsesCurrentLocation

        if savedUsesCurrentLocation, UserDefaults.standard.object(forKey: "selectedLat") != nil {
            let lat = UserDefaults.standard.double(forKey: "selectedLat")
            let lon = UserDefaults.standard.double(forKey: "selectedLon")
            let name = UserDefaults.standard.string(forKey: "selectedCity") ?? "Huidige locatie"
            self.location = LocationConfig(name: name, latitude: lat, longitude: lon)
        } else if let savedName = UserDefaults.standard.string(forKey: "selectedCity"),
           let savedCity = LocationConfig.allCities.first(where: { $0.name == savedName }) {
            self.location = savedCity
        } else if UserDefaults.standard.object(forKey: "selectedLat") != nil {
            let lat = UserDefaults.standard.double(forKey: "selectedLat")
            let lon = UserDefaults.standard.double(forKey: "selectedLon")
            let name = UserDefaults.standard.string(forKey: "selectedCity") ?? "Eigen locatie"
            self.location = LocationConfig(name: name, latitude: lat, longitude: lon)
        } else {
            self.location = .amsterdam
        }
    }

    func updateFromCurrentLocation(latitude: Double, longitude: Double, cityName: String) {
        usesCurrentLocation = true
        location = LocationConfig(name: cityName, latitude: latitude, longitude: longitude)
    }

    func selectCity(_ city: LocationConfig) {
        usesCurrentLocation = false
        location = city
    }

    func fetchRainData(session: URLSession = .shared) async {
        let id = UUID()
        requestID = id
        isLoading = true
        errorMessage = nil
        defer { if requestID == id { isLoading = false } }
        let urlString = "https://gpsgadget.buienradar.nl/data/raintext?lat=\(location.latitude)&lon=\(location.longitude)"
        guard let url = URL(string: urlString) else {
            errorMessage = "Ongeldig regenadres."
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let text = String(data: data, encoding: .utf8) else { throw ForecastError.invalidData }
            let newReadings = text.components(separatedBy: .newlines).compactMap { line -> RainReading? in
                let parts = line.components(separatedBy: "|")
                guard parts.count == 2, let intensity = Double(parts[0]), (0...255).contains(intensity) else { return nil }
                let time = parts[1].trimmingCharacters(in: .whitespaces)
                let clock = time.split(separator: ":")
                guard clock.count == 2, clock[0].count == 2, clock[1].count == 2,
                      let hour = Int(clock[0]), (0...23).contains(hour),
                      let minute = Int(clock[1]), (0...59).contains(minute) else { return nil }
                return RainReading(time: time, intensity: intensity)
            }
            guard newReadings.count >= 2 else { throw ForecastError.invalidData }
            try Task.checkCancellation()
            guard requestID == id else { return }
            readings = newReadings
            lastUpdated = Date()
        } catch {
            guard requestID == id, !Task.isCancelled else { return }
            errorMessage = "Regen ophalen mislukt. Controleer je verbinding en probeer opnieuw."
        }
    }
}
