import SwiftUI

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
    var refreshTimer: Timer?
    var miniGraphLayer: CALayer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            updateMenuBarDisplay()
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 440, height: 360)
        popover.behavior = .transient
        let hostingController = NSHostingController(
            rootView: RainPopoverView(rainService: rainService)
        )
        popover.contentViewController = hostingController

        Task {
            await rainService.fetchRainData()
            updateMenuBarDisplay()
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.rainService.fetchRainData()
                self.updateMenuBarDisplay()
            }
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
            symbolName = "cloud.sun"
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Rain status") {
            image.isTemplate = true
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = image.withSymbolConfiguration(config)
        }

        button.title = " " + rainService.menuBarText
        button.imagePosition = .imageLeading

        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        button.attributedTitle = NSAttributedString(string: " " + rainService.menuBarText, attributes: attrs)
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()

            Task {
                await rainService.fetchRainData()
                updateMenuBarDisplay()
            }
        }
    }
}
