import DialCore
import SwiftUI

struct SetupImportSheet: View {
    let preview: ImportPreview
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var _selectedIDs: State<Set<String>>
    private var selectedIDs: Set<String> {
        get { _selectedIDs.wrappedValue }
        nonmutating set { _selectedIDs.wrappedValue = newValue }
    }

    init(preview: ImportPreview, appState: AppState) {
        self.preview = preview
        self.appState = appState
        let initial = Set(
            preview.items
                .filter { $0.status == .willChange }
                .map(\.id)
        )
        self._selectedIDs = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Setup: \(preview.name)")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Select which preferences to apply. A snapshot will be saved automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(selectedIDs.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            List {
                ForEach(preview.items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { selectedIDs.contains(item.id) },
                                set: { isOn in
                                    if isOn {
                                        selectedIDs.insert(item.id)
                                    } else {
                                        selectedIDs.remove(item.id)
                                    }
                                }
                            )
                        )
                        .labelsHidden()
                        .disabled(!item.isSelectable)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(item.tweak?.name ?? item.id)
                                    .fontWeight(.medium)
                                statusBadge(item.status)
                            }

                            if let desc = item.tweak?.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 6) {
                                Text(item.currentSummary)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(item.targetSummary)
                                    .fontWeight(.medium)
                            }
                            .font(.caption.monospaced())

                            if !item.missingPrerequisites.isEmpty {
                                Label(
                                    "Requires: \(item.missingPrerequisites.map(\.tweakID).joined(separator: ", "))",
                                    systemImage: "exclamationmark.triangle"
                                )
                                .font(.caption)
                                .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button("Select All Changing") {
                    selectedIDs = Set(preview.items.filter(\.isSelectable).map(\.id))
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Cancel", role: .cancel) {
                    appState.activeImportPreview = nil
                    dismiss()
                }

                Button("Apply Selected") {
                    Task {
                        await appState.applyImport(
                            items: preview.items,
                            selectedIDs: selectedIDs,
                            setupName: preview.name
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIDs.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    @ViewBuilder
    private func statusBadge(_ status: ImportItemStatus) -> some View {
        switch status {
        case .willChange:
            badge("Will Change", color: .blue)
        case .alreadyActive:
            badge("Already Active", color: .green)
        case .conflict(let withIDs):
            badge("Conflict (\(withIDs.joined(separator: ", ")))", color: .red)
        case .unsupportedOS(let required):
            badge("Requires macOS \(required.formatted)", color: .orange)
        case .unknown:
            badge("Unknown ID", color: .secondary)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
