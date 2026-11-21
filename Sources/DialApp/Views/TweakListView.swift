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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(appState.searchText.isEmpty ? section.title : "Search Results")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("\(tweaks.count)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(appState.currentOSDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.quaternary.opacity(0.6), in: Capsule())
                        }
                        .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(tweaks.enumerated()), id: \.element.id) { index, tweak in
                                TweakRowView(tweak: tweak, appState: appState)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                if index < tweaks.count - 1 {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
                        )
                    }
                    .padding(24)
                    .padding(.bottom, 56)
                }
            }
        }
        .navigationTitle(appState.searchText.isEmpty ? section.title : "Search")
    }
}
