import SwiftUI
import Combine
import Sparkle

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
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var rainService = RainService()
    var weatherService = WeatherService()
    var refreshTimer: Timer?
    let presentation = PopoverPresentation()
    private var updaterController: SPUStandardUpdaterController!
    private var refreshTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateMenuBarDisplay()
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 500, height: 340)
        popover.behavior = .transient
        popover.delegate = self
        let hostingController = NSHostingController(
            rootView: RainPopoverView(rainService: rainService, weatherService: weatherService,
                                      refresh: { [weak self] in self?.refreshData() },
                                      presentation: presentation, onSizeChange: { [weak self] size in
                                          guard let self, size.width > 0, size.height > 0,
                                                self.popover.contentSize != size else { return }
                                          self.popover.contentSize = size
                                      })
        )
        hostingController.sizingOptions = [.preferredContentSize]
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
        let opening = presentation.openingID
        weatherService.prepare(for: location)
        refreshTask = Task { [weak self] in
            guard let self else { return }
            async let rain: Void = self.rainService.fetchRainData()
            async let weather: Void = self.weatherService.fetch(for: location)
            _ = await rain
            guard !Task.isCancelled else { _ = await weather; return }
            if !self.rainService.readings.isEmpty {
                self.presentation.updateForecast(hasRain: self.rainService.hasRainComing, opening: opening)
            }
            _ = await weather
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

    func popoverDidClose(_ notification: Notification) { presentation.close() }

    private func showUpdateMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        menu.addItem(withTitle: "RainBar \(version)", action: nil, keyEquivalent: "")
        let check = menu.addItem(withTitle: "Zoek naar updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        check.target = self
        check.isEnabled = updaterController.updater.canCheckForUpdates
        let automatic = menu.addItem(withTitle: "Automatisch bijwerken", action: #selector(toggleAutomaticUpdates), keyEquivalent: "")
        automatic.target = self
        automatic.state = updaterController.updater.automaticallyChecksForUpdates && updaterController.updater.automaticallyDownloadsUpdates ? .on : .off
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "RainBar afsluiten", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func checkForUpdates() { updaterController.checkForUpdates(nil) }
    @objc private func toggleAutomaticUpdates() {
        let enabled = !(updaterController.updater.automaticallyChecksForUpdates && updaterController.updater.automaticallyDownloadsUpdates)
        updaterController.updater.automaticallyChecksForUpdates = enabled
        updaterController.updater.automaticallyDownloadsUpdates = enabled
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if NSApp.currentEvent?.type == .rightMouseUp {
            showUpdateMenu()
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            presentation.open(hasRain: rainService.hasRainComing)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()

            refreshData()
        }
    }
}
