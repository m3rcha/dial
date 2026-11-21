import DialCore
import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show Dial in Menu Bar", isOn: $appState.showMenuBarExtra)
                Text("Quickly switch profiles or export your Mac's setup from the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Community Registry") {
                TextField("Feed URL (HTTPS)", text: $appState.communityFeedURL)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    if !CommunityFeedClient.validateFeedURL(appState.communityFeedURL) {
                        Label("URL must use HTTPS", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Button("Reset Default") {
                        appState.communityFeedURL = CommunityFeedClient.defaultFeedURLString
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 240)
    }
}
