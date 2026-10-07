import Foundation

final class MockProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data, Double))!
    private var pending: DispatchWorkItem?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data, delay) = Self.handler(request)
        let pending = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let response = HTTPURLResponse(url: self.request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        self.pending = pending
        DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: pending)
    }
    override func stopLoading() { pending?.cancel() }
}

func require(_ value: @autoclosure () -> Bool, _ message: String) {
    if !value() { fatalError(message) }
    print("PASS: \(message)")
}

@main struct ForecastTests {
    @MainActor static func main() async throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/weather.json"))
        let forecast = try WeatherForecast.decode(data)
        require(forecast.days.count == 5, "five-day forecast decodes")
        require(forecast.hours.count == 120, "hourly forecast decodes")
        let upcoming = forecast.upcomingHours(now: forecast.observedAt)
        require(upcoming.count == 12 && upcoming[0].date <= forecast.observedAt,
                "12-hour window includes current hour, excludes earlier hours")
        require(WeatherCondition.description(0, isDay: false) == "Helder" && WeatherCondition.symbol(0, isDay: false).contains("moon"), "clear night is not sunny")
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var daily = object["daily"] as! [String: Any]
        let seconds = (daily["sunshine_duration"] as! [Double])[0]
        require(abs(forecast.days[0].sunshineHours! - seconds / 3600) < 0.001, "sunshine seconds converted to hours")
        var sunshine = daily["sunshine_duration"] as! [Any]
        sunshine[0] = NSNull()
        daily["sunshine_duration"] = sunshine
        object["daily"] = daily
        let nullForecast = try WeatherForecast.decode(JSONSerialization.data(withJSONObject: object))
        require(nullForecast.days[0].sunshineHours == nil && nullForecast.days.count == 5, "missing sunshine stays unavailable, not zero")
        daily["weather_code"] = []
        object["daily"] = daily
        do {
            _ = try WeatherForecast.decode(JSONSerialization.data(withJSONObject: object))
            fatalError("Malformed arrays accepted")
        } catch { print("PASS: mismatched arrays rejected") }

        var enriched = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var hourly = enriched["hourly"] as! [String: Any]
        hourly["apparent_temperature"] = Array(repeating: 15.0, count: 120)
        hourly["precipitation_probability"] = Array(repeating: 40, count: 120)
        hourly["precipitation"] = Array(repeating: 0.1, count: 120)
        hourly["wind_speed_10m"] = Array(repeating: 12.0, count: 120)
        enriched["hourly"] = hourly
        let detailed = try WeatherForecast.decode(JSONSerialization.data(withJSONObject: enriched))
        require(detailed.hours[0].rainMM == 0.1 && detailed.hours[0].rainProbability == 40 && detailed.hours[0].windKPH == 12 && detailed.hours[0].feelsLike == 15, "hourly day details decode with units intact")
        require(forecast.hours[0].rainMM == nil, "missing optional hourly fields stay unavailable")
        hourly["precipitation"] = []
        enriched["hourly"] = hourly
        do {
            _ = try WeatherForecast.decode(JSONSerialization.data(withJSONObject: enriched))
            fatalError("Malformed optional array accepted")
        } catch { print("PASS: mismatched optional arrays rejected") }
        let day = detailed.days[0]
        require(detailed.hours(for: day.date).count == 24, "day details include exactly matching calendar day")
        let evening = detailed.hours(for: day.date, period: .evening)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        require(evening.count == 6 && evening.allSatisfy { calendar.component(.hour, from: $0.date) >= 18 }, "evening selects 18:00 through 23:00")
        require(detailed.hours(for: day.date, period: .morning).count == 6 && detailed.hours(for: day.date, period: .afternoon).count == 6, "morning and afternoon each contain six hours")
        let dstStart = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25))!
        let dstEnd = calendar.date(byAdding: .day, value: 1, to: dstStart)!
        let dstHours = stride(from: dstStart.timeIntervalSince1970, through: dstEnd.timeIntervalSince1970, by: 3600).map {
            HourForecast(date: Date(timeIntervalSince1970: $0), temperature: 10, code: 0, isDay: false)
        }
        let dst = WeatherForecast(observedAt: dstStart, temperature: 10, feelsLike: 10, code: 0, isDay: false, hours: dstHours, days: [day])
        require(dst.hours(for: dstStart).count == 25 && dst.hours(for: dstStart, period: .evening).count == 6, "Dutch daylight-saving day keeps both repeated hours and excludes next midnight")
        let drizzle = [RainReading(time: "21:50", intensity: 77), RainReading(time: "21:55", intensity: 77)]
        require(RainChartScale.upperBound(for: drizzle) == 0.2, "0.1 mm/h drizzle occupies half a labelled chart")
        let heavy = [RainReading(time: "12:00", intensity: 200)]
        require(RainChartScale.upperBound(for: heavy) > heavy[0].mmPerHour, "heavy rain stays inside adaptive chart domain")
        let presentation = PopoverPresentation()
        presentation.open(hasRain: false)
        require(presentation.selectedTab == .weather, "dry opening selects weather")
        let opening = presentation.openingID
        presentation.updateForecast(hasRain: true, opening: opening)
        require(presentation.selectedTab == .rain, "fresh rain data refines opening tab")
        presentation.updateForecast(hasRain: false, opening: opening)
        require(presentation.selectedTab == .rain, "later timer refresh does not change automatically opened tab")
        presentation.select(.weather)
        presentation.updateForecast(hasRain: true, opening: opening)
        require(presentation.selectedTab == .weather, "refresh preserves manual tab choice")
        presentation.close()
        presentation.open(hasRain: true)
        require(presentation.selectedTab == .rain, "new rainy opening resets manual choice")
        presentation.updateForecast(hasRain: false, opening: opening)
        require(presentation.selectedTab == .rain, "late result from prior opening cannot change tab")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockProtocol.self]
        let session = URLSession(configuration: config)
        MockProtocol.handler = { _ in (200, data, 0) }
        let weather = WeatherService()
        await weather.fetch(for: .amsterdam, session: session)
        require(weather.forecast != nil && !weather.isLoading && weather.errorMessage == nil, "weather success updates state")
        MockProtocol.handler = { _ in (503, Data(), 0) }
        await weather.fetch(for: .amsterdam, session: session)
        require(weather.forecast != nil && weather.errorMessage != nil && !weather.isLoading, "weather outage preserves data and shows error")
        weather.prepare(for: .rotterdam)
        require(weather.forecast == nil && weather.lastUpdated == nil && weather.errorMessage == nil, "location switch clears old weather")

        var other = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var current = other["current"] as! [String: Any]
        current["temperature_2m"] = 23.0
        other["current"] = current
        let newData = try JSONSerialization.data(withJSONObject: other)
        MockProtocol.handler = { request in
            let latitude = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "latitude" }!.value!
            return latitude.hasPrefix("52.") ? (200, data, 0.25) : (200, newData, 0.01)
        }
        let old = Task { await weather.fetch(for: .amsterdam, session: session) }
        try await Task.sleep(for: .milliseconds(25))
        await weather.fetch(for: .rotterdam, session: session)
        await old.value
        require(weather.forecast?.temperature == 23, "late response cannot replace new location weather")

        let rain = RainService()
        MockProtocol.handler = { _ in (200, Data("000|23:55\n109|00:00\n".utf8), 0) }
        await rain.fetchRainData(session: session)
        require(rain.readings.count == 2 && rain.menuBarText == "Regen 00:00", "rain parses midnight and Dutch upcoming status")
        rain.readings = [RainReading(time: "12:00", intensity: 109), RainReading(time: "12:05", intensity: 0)]
        require(rain.menuBarText == "1,0 mm/u", "Dutch decimal and rain units")
        rain.readings = [RainReading(time: "12:00", intensity: 0), RainReading(time: "12:05", intensity: 0)]
        require(rain.menuBarText == "Droog", "Dutch dry status")
        rain.selectCity(.rotterdam)
        require(rain.readings.isEmpty && rain.lastUpdated == nil, "location switch clears old rain")
        MockProtocol.handler = { _ in (200, Data("<html>Unavailable</html>".utf8), 0) }
        await rain.fetchRainData(session: session)
        require(rain.errorMessage != nil && rain.menuBarText == "Geen data", "invalid rain response is not dry weather")
        MockProtocol.handler = { _ in (200, Data("000|19:00\n000|19:05\n".utf8), 0.15) }
        let oldRain = Task { await rain.fetchRainData(session: session) }
        try await Task.sleep(for: .milliseconds(20))
        rain.selectCity(.utrecht)
        await oldRain.value
        require(rain.readings.isEmpty, "late rain response ignored after location change")

        if !CommandLine.arguments.contains("--offline") {
            await weather.fetch(for: .amsterdam)
            require(weather.forecast?.days.count == 5 && weather.forecast?.upcomingHours().count == 12, "live Open-Meteo request passes")
            await rain.fetchRainData()
            require(rain.readings.count == 24 && rain.errorMessage == nil, "live Buienradar request passes")
            require(weather.forecast?.hours.first?.windKPH != nil && weather.forecast?.hours.first?.rainProbability != nil, "live source supplies day detail fields")
        }
        print("ALL CHECKS PASSED")
    }
}
