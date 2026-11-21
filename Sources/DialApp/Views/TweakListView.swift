import DialCore
import SwiftUI

struct TweakListView: View {
    let section: SidebarSection
    @Bindable var appState: AppState

    private var tweaks: [Tweak] {
        appState.filteredTweaks(for: section)
    }

    var body: some View {
        Group {
            if tweaks.isEmpty {
                ContentUnavailableView {
                    Label(
                        appState.searchText.isEmpty ? "No Tweaks" : "No Matching Tweaks",
                        systemImage: appState.searchText.isEmpty ? "slider.horizontal.3" : "magnifyingglass"
                    )
                } description: {
                    if section == .modified && appState.searchText.isEmpty {
                        Text("Tweaks that differ from stock macOS defaults will appear here.")
                    } else if !appState.searchText.isEmpty {
                        Text("Try searching by tweak name or defaults key (e.g. autohide, AppleShowAllFiles).")
                    }
                }
            } else {
                Form {
                    Section {
                        ForEach(tweaks) { tweak in
                            TweakRowView(tweak: tweak, appState: appState)
                        }
                    } header: {
                        HStack {
                            Text(appState.searchText.isEmpty ? section.title : "Search Results (\(tweaks.count))")
                            Spacer()
                            Text(appState.currentOSDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
        .navigationTitle(appState.searchText.isEmpty ? section.title : "Search")
    }
}
