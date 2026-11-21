import AppKit
import DialCore
import SwiftUI

@main
struct DialApp: App {
    private let appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .frame(minWidth: 820, minHeight: 540)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    appState.refreshLiveState()
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
            }
        }
    }
}
