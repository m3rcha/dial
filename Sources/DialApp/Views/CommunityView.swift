import DialCore
import SwiftUI

struct CommunityView: View {
    @Bindable var appState: AppState

    var body: some View {
        Group {
            if appState.isLoadingCommunity {
                ProgressView("Loading community tweaks...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.communityTweaks.isEmpty {
                ContentUnavailableView {
                    Label("Community Tweaks", systemImage: "globe")
                } description: {
                    if let error = appState.communityErrorMessage {
                        Text(error)
                    } else {
                        Text("Fetch declarative community tweaks from the Dial registry feed or paste a dial:v1: setup code.")
                    }
                } actions: {
                    Button("Refresh Feed") {
                        Task { await appState.refreshCommunityFeed() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                TweakListView(section: .community, appState: appState)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await appState.refreshCommunityFeed() }
                } label: {
                    Label("Refresh Community Feed", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isLoadingCommunity)
            }
        }
        .navigationTitle("Community")
    }
}
