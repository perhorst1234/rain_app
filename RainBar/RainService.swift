import Foundation

struct RainReading: Identifiable {
    let id = UUID()
    let time: String
    let intensity: Double

    var mmPerHour: Double {
        guard intensity > 0 else { return 0 }
        return pow(10, (intensity - 109) / 32)
    }

    var description: String {
        if mmPerHour == 0 { return "Dry" }
        if mmPerHour < 0.5 { return "Light drizzle" }
        if mmPerHour < 2.0 { return "Light rain" }
        if mmPerHour < 5.0 { return "Moderate rain" }
        if mmPerHour < 10.0 { return "Heavy rain" }
        return "Very heavy rain"
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
        if readings.isEmpty { return "..." }
        if isRainingNow {
            let mm = currentRainMM
            if mm < 0.1 { return "0.1 mm/h" }
            return String(format: "%.1f mm/h", mm)
        }
        if let nextRain = nextRainTime {
            return "Rain \(nextRain)"
        }
        return "Dry"
    }

    init() {
        let savedUsesCurrentLocation = UserDefaults.standard.bool(forKey: "usesCurrentLocation")
        self.usesCurrentLocation = savedUsesCurrentLocation

        if savedUsesCurrentLocation, UserDefaults.standard.object(forKey: "selectedLat") != nil {
            let lat = UserDefaults.standard.double(forKey: "selectedLat")
            let lon = UserDefaults.standard.double(forKey: "selectedLon")
            let name = UserDefaults.standard.string(forKey: "selectedCity") ?? "Current Location"
            self.location = LocationConfig(name: name, latitude: lat, longitude: lon)
        } else if let savedName = UserDefaults.standard.string(forKey: "selectedCity"),
           let savedCity = LocationConfig.allCities.first(where: { $0.name == savedName }) {
            self.location = savedCity
        } else if UserDefaults.standard.object(forKey: "selectedLat") != nil {
            let lat = UserDefaults.standard.double(forKey: "selectedLat")
            let lon = UserDefaults.standard.double(forKey: "selectedLon")
            let name = UserDefaults.standard.string(forKey: "selectedCity") ?? "Custom"
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

    func fetchRainData() async {
        isLoading = true
        errorMessage = nil

        let urlString = "https://gpsgadget.buienradar.nl/data/raintext?lat=\(location.latitude)&lon=\(location.longitude)"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let text = String(data: data, encoding: .utf8) else {
                errorMessage = "Could not decode response"
                isLoading = false
                return
            }

            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            var newReadings: [RainReading] = []

            for line in lines {
                let parts = line.components(separatedBy: "|")
                guard parts.count == 2,
                      let intensity = Double(parts[0].trimmingCharacters(in: .whitespaces)) else {
                    continue
                }
                let time = parts[1].trimmingCharacters(in: .whitespaces)
                newReadings.append(RainReading(time: time, intensity: intensity))
            }

            readings = newReadings
            lastUpdated = Date()
            isLoading = false
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
            isLoading = false
        }
    }
}
