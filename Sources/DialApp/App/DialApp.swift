import AppKit
import DialCore
import SwiftUI

@main
struct DialApp: App {
    private let appState: AppState
    private let menuBarController: MenuBarController

    init() {
        let state = AppState()
        let menuBar = MenuBarController(appState: state)
        state.onMenuBarSettingChanged = { enabled in
            menuBar.setEnabled(enabled)
        }
        self.appState = state
        self.menuBarController = menuBar
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .frame(minWidth: 820, minHeight: 540)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    appState.refreshLiveState()
                    menuBarController.rebuildMenu()
                }
                .onOpenURL { url in
                    if let code = SetupCodeCodec.extractCode(from: url) {
                        appState.handleIncomingSetupString(code)
                    }
                }
        }
        .commands {
            CommandGroup(after: .pasteboard) {
                Button("Import Setup Code from Clipboard") {
                    appState.handlePasteFromClipboard()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("Export My Mac Setup Code") {
                    appState.exportMyMacToPasteboard()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView(appState: appState)
        }
    }
}
