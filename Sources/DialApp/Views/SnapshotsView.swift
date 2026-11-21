import DialCore
import SwiftUI

struct SnapshotsView: View {
    @Bindable var appState: AppState

    var body: some View {
        Group {
            if appState.snapshots.isEmpty {
                ContentUnavailableView(
                    "No Snapshots Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Dial automatically captures a reversible snapshot before any change or Setup Code import.")
                )
            } else {
                Form {
                    Section("Rollback History") {
                        ForEach(appState.snapshots) { entry in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.title)
                                        .fontWeight(.medium)
                                    Text("\(entry.changes.count) preference change(s) • \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Revert") {
                                    Task { await appState.revertSnapshot(entry) }
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
        .navigationTitle("Snapshots")
    }
}
