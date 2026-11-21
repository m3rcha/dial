import DialCore
import SwiftUI

struct SidebarView: View {
    @Bindable var appState: AppState

    var body: some View {
        List(selection: $appState.selection) {
            Section("Library") {
                sidebarRow(
                    title: "Modified",
                    systemImage: "slider.horizontal.2.square",
                    count: appState.modifiedTweakIDs.count,
                    section: .modified
                )
                sidebarRow(
                    title: "Profiles",
                    systemImage: "square.stack.3d.up",
                    count: appState.profiles.count,
                    section: .profiles
                )
                sidebarRow(
                    title: "Snapshots",
                    systemImage: "clock.arrow.circlepath",
                    count: appState.snapshots.count,
                    section: .snapshots
                )
                sidebarRow(
                    title: "Community",
                    systemImage: "globe",
                    count: appState.communityTweaks.count,
                    section: .community
                )
            }

            Section("Categories") {
                ForEach(TweakCategory.allCases) { category in
                    sidebarRow(
                        title: category.rawValue,
                        systemImage: category.symbolName,
                        count: appState.modifiedCount(for: category),
                        section: .category(category)
                    )
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarRow(
        title: String,
        systemImage: String,
        count: Int,
        section: SidebarSection
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
        }
        .tag(section)
    }
}
