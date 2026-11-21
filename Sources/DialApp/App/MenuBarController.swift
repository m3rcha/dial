import AppKit
import DialCore

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        setEnabled(appState.showMenuBarExtra)
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                item.button?.image = NSImage(systemSymbolName: "dial.medium", accessibilityDescription: "Dial")
                statusItem = item
            }
            rebuildMenu()
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }

    func rebuildMenu() {
        guard let statusItem, let appState else { return }
        let menu = NSMenu()

        let header = NSMenuItem(title: "Dial Profiles", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for profile in appState.profiles {
            let item = NSMenuItem(title: profile.name, action: #selector(activateProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let exportItem = NSMenuItem(title: "Export My Mac Setup Code", action: #selector(exportSetup), keyEquivalent: "")
        exportItem.target = self
        menu.addItem(exportItem)

        let openItem = NSMenuItem(title: "Open Dial", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        statusItem.menu = menu
    }

    @objc private func activateProfile(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? Profile, let appState else { return }
        Task { @MainActor in
            await appState.activateProfile(profile)
        }
    }

    @objc private func exportSetup() {
        appState?.exportMyMacToPasteboard()
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}
