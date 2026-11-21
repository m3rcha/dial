import DialCore
import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        } detail: {
            detailView
        }
        .searchable(
            text: $appState.searchText,
            placement: .toolbar,
            prompt: "Search tweaks or defaults keys"
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appState.handlePasteFromClipboard()
                } label: {
                    Label("Import Code", systemImage: "square.and.arrow.down")
                }
                .help("Import a dial:v1: setup code from clipboard (⌘V)")

                Button {
                    appState.exportMyMacToPasteboard()
                } label: {
                    Label("Export My Mac", systemImage: "square.and.arrow.up")
                }
                .help("Copy your Mac's modified tweaks as a dial:v1: setup code")
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = appState.toastMessage {
                Text(toast)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .adaptiveCapsuleSurface()
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: appState.toastMessage)
        .alert(
            "Could Not Import Setup Code",
            isPresented: Binding(
                get: { appState.importErrorMessage != nil },
                set: { if !$0 { appState.importErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.importErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let current = appState.selection ?? .category(.dock)
        if !appState.searchText.isEmpty {
            TweakListView(section: current, appState: appState)
        } else {
            switch current {
            case .category, .modified:
                TweakListView(section: current, appState: appState)
            case .profiles:
                Text("Profiles")
                    .navigationTitle("Profiles")
            case .snapshots:
                Text("Snapshots")
                    .navigationTitle("Snapshots")
            case .community:
                Text("Community")
                    .navigationTitle("Community")
            }
        }
    }
}
