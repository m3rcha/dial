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
                .help("Import a dial:v1: setup code from clipboard (⇧⌘V)")

                Button {
                    appState.exportMyMacToPasteboard()
                } label: {
                    Label("Export My Mac", systemImage: "square.and.arrow.up")
                }
                .help("Copy your Mac's modified tweaks as a dial:v1: setup code")
            }
        }
        .overlay(alignment: .bottom) {
            AdaptiveGlassContainer {
                VStack(spacing: 8) {
                    if !appState.pendingServices.isEmpty {
                        RestartCapsuleView(appState: appState)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if let toast = appState.toastMessage {
                        Text(toast)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .adaptiveCapsuleSurface()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .animation(.snappy, value: appState.toastMessage)
        .animation(.snappy, value: appState.pendingServices.isEmpty)
        .sheet(item: Binding(
            get: { appState.activeImportPreview.map { PreviewWrapper(preview: $0) } },
            set: { if $0 == nil { appState.activeImportPreview = nil } }
        )) { wrapper in
            SetupImportSheet(preview: wrapper.preview, appState: appState)
        }
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
                ProfilesView(appState: appState)
            case .snapshots:
                SnapshotsView(appState: appState)
            case .community:
                CommunityView(appState: appState)
            }
        }
    }
}

private struct PreviewWrapper: Identifiable {
    let id = UUID()
    let preview: ImportPreview
}
