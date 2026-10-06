import SwiftUI
import Combine

@main
struct RainBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var rainService = RainService()
    var weatherService = WeatherService()
    var refreshTimer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            updateMenuBarDisplay()
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 460, height: 560)
        popover.behavior = .transient
        let hostingController = NSHostingController(
            rootView: RainPopoverView(rainService: rainService, weatherService: weatherService,
                                      refresh: { [weak self] in self?.refreshData() })
        )
        popover.contentViewController = hostingController

        Publishers.Merge(rainService.objectWillChange, weatherService.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateMenuBarDisplay() }
            .store(in: &subscriptions)
        refreshData()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshData() }
        }
    }

    func refreshData() {
        refreshTask?.cancel()
        let location = rainService.location
        weatherService.prepare(for: location)
        refreshTask = Task { [weak self] in
            guard let self else { return }
            async let rain: Void = self.rainService.fetchRainData()
            async let weather: Void = self.weatherService.fetch(for: location)
            _ = await (rain, weather)
        }
    }

    func updateMenuBarDisplay() {
        guard let button = statusItem.button else { return }

        let symbolName: String
        if rainService.readings.isEmpty {
            symbolName = "cloud"
        } else if rainService.isRainingNow {
            symbolName = "cloud.rain.fill"
        } else if rainService.hasRainComing {
            symbolName = "cloud.rain"
        } else {
            symbolName = weatherService.forecast.map {
                WeatherCondition.symbol($0.code, isDay: $0.isDay)
            } ?? "cloud"
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Regen en weer") {
            image.isTemplate = true
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = image.withSymbolConfiguration(config)
        }

        let temperature = weatherService.forecast.map {
            " · \($0.temperature.formatted(.number.locale(Locale(identifier: "nl_NL")).precision(.fractionLength(0))))°"
        } ?? ""
        let title = " " + rainService.menuBarText + temperature
        button.title = title
        button.imagePosition = .imageLeading

        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        button.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        button.toolTip = "RainBar · \(rainService.location.name) · Regen en weer"
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()

            refreshData()
        }
    }
}
