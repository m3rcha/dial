import DialCore
import SwiftUI

struct SidebarView: View {
    @Bindable var appState: AppState

    var body: some View {
        List(selection: $appState.selection) {
            Section("Library") {
                NavigationLink(value: SidebarSection.modified) {
                    Label("Modified", systemImage: "slider.horizontal.2.square")
                }
                .badge(appState.modifiedTweakIDs.count)

                NavigationLink(value: SidebarSection.profiles) {
                    Label("Profiles", systemImage: "square.stack.3d.up")
                }
                .badge(appState.profiles.count)

                NavigationLink(value: SidebarSection.snapshots) {
                    Label("Snapshots", systemImage: "clock.arrow.circlepath")
                }
                .badge(appState.snapshots.count)

                NavigationLink(value: SidebarSection.community) {
                    Label("Community", systemImage: "globe")
                }
                .badge(appState.communityTweaks.count)
            }

            Section("Categories") {
                ForEach(TweakCategory.allCases) { category in
                    NavigationLink(value: SidebarSection.category(category)) {
                        Label(category.rawValue, systemImage: category.symbolName)
                    }
                    .badge(appState.modifiedCount(for: category))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Dial")
    }
}
