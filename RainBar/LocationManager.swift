import CoreLocation

@MainActor
class LocationManager: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var cityName: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocating = false
    @Published var error: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
    }

    func requestLocation() {
        isLocating = true
        error = nil
        cityName = nil
        geocoder.cancelGeocode()

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorized:
            manager.requestLocation()
        case .denied, .restricted:
            error = "Locatietoegang geweigerd. Schakel dit in via Systeeminstellingen > Privacy en beveiliging > Locatievoorzieningen."
            isLocating = false
        @unknown default:
            manager.requestWhenInUseAuthorization()
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                guard let self = self else { return }
                if let placemark = placemarks?.first {
                    self.cityName = placemark.locality ?? placemark.subAdministrativeArea ?? "Huidige locatie"
                } else {
                    self.cityName = "Huidige locatie"
                }
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            self.isLocating = false
            self.reverseGeocode(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = "Locatie bepalen mislukt."
            self.isLocating = false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorized {
                manager.requestLocation()
            }
        }
    }
}
