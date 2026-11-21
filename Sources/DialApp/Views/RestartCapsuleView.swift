import DialCore
import SwiftUI

struct RestartCapsuleView: View {
    @Bindable var appState: AppState

    private var serviceNames: String {
        appState.pendingServices
            .map(\.rawValue)
            .sorted()
            .joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)

            Text("Restart \(serviceNames) to apply changes")
                .font(.subheadline)

            Button {
                Task { await appState.restartPendingServices() }
            } label: {
                if appState.isRestartingServices {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Restart Now")
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(appState.isRestartingServices)

            Button {
                appState.pendingServices.removeAll()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .adaptiveCapsuleSurface(interactive: true)
    }
}
