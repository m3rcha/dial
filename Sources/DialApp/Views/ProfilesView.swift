import DialCore
import SwiftUI

struct ProfilesView: View {
    @Bindable var appState: AppState

    private var _newProfileName = State(initialValue: "")
    private var _showSaveSheet = State(initialValue: false)

    private var newProfileName: String {
        get { _newProfileName.wrappedValue }
        nonmutating set { _newProfileName.wrappedValue = newValue }
    }

    private var showSaveSheet: Bool {
        get { _showSaveSheet.wrappedValue }
        nonmutating set { _showSaveSheet.wrappedValue = newValue }
    }

    var body: some View {
        Form {
            Section {
                ForEach(appState.profiles) { profile in
                    HStack(spacing: 12) {
                        Image(systemName: profile.symbolName)
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(profile.name)
                                    .fontWeight(.medium)
                                if profile.isBuiltIn {
                                    Text("Built-in")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.secondary.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(profile.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !profile.isBuiltIn {
                            Button(role: .destructive) {
                                appState.deleteUserProfile(profile)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }

                        Button("Activate") {
                            Task { await appState.activateProfile(profile) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("Profiles")
                    Spacer()
                    Button {
                        newProfileName = ""
                        showSaveSheet = true
                    } label: {
                        Label("Save Current Mac as Profile", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Profiles")
        .sheet(isPresented: _showSaveSheet.projectedValue) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Save Current Profile")
                    .font(.headline)
                TextField("Profile name (e.g. Work, Streaming)", text: _newProfileName.projectedValue)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { showSaveSheet = false }
                    Button("Save") {
                        appState.saveCurrentAsProfile(name: newProfileName)
                        showSaveSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(width: 340)
        }
    }
}
