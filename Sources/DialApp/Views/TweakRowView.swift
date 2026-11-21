import DialCore
import SwiftUI

struct TweakRowView: View {
    let tweak: Tweak
    @Bindable var appState: AppState

    private var _showRiskConfirmation = State(initialValue: false)
    private var showRiskConfirmation: Bool {
        get { _showRiskConfirmation.wrappedValue }
        nonmutating set { _showRiskConfirmation.wrappedValue = newValue }
    }

    private var isActive: Bool {
        appState.activeTweakIDs.contains(tweak.id)
    }

    private var isModified: Bool {
        appState.modifiedTweakIDs.contains(tweak.id)
    }

    private var unmetPrereqs: [TweakPrerequisite] {
        appState.unmetPrerequisites(for: tweak)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(tweak.name)
                            .font(.body)
                            .fontWeight(.medium)

                        if tweak.riskLevel == .advanced {
                            Text("Advanced")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.16), in: Capsule())
                                .foregroundStyle(.orange)
                        }

                        if tweak.source == .community {
                            Text("Community")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.14), in: Capsule())
                                .foregroundStyle(.blue)
                        }
                    }

                    Text(tweak.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                if isModified {
                    Button {
                        Task { await appState.resetToStock(tweak) }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .help("Reset to macOS default")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }

                Toggle(
                    "",
                    isOn: Binding(
                        get: { isActive },
                        set: { newValue in
                            if newValue && tweak.riskLevel == .advanced {
                                showRiskConfirmation = true
                            } else {
                                Task { await appState.setTweak(tweak, enabled: newValue) }
                            }
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }

            if let parameters = tweak.parameters, !parameters.isEmpty {
                ForEach(parameters) { param in
                    parameterControlView(param)
                        .padding(.top, 2)
                }
            }

            if !unmetPrereqs.isEmpty {
                Label(
                    "Requires: \(unmetPrereqs.map(\.tweakID).joined(separator: ", "))",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            if let note = tweak.osNote {
                Label(note, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "Apply \"\(tweak.name)\"?",
            isPresented: _showRiskConfirmation.projectedValue,
            titleVisibility: .visible
        ) {
            Button("Apply") {
                Task { await appState.setTweak(tweak, enabled: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is marked as an advanced system preference. You can revert it at any time.")
        }
    }

    @ViewBuilder
    private func parameterControlView(_ param: TweakParameter) -> some View {
        let currentValue = appState.parameterValues[tweak.id]?[param.id] ?? param.defaultValue

        switch param.control {
        case .slider(let minVal, let maxVal, let step, let unit):
            let doubleValue = currentValue.asDouble ?? param.defaultValue.asDouble ?? minVal
            HStack(spacing: 12) {
                Text(param.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { doubleValue },
                        set: { newVal in
                            appState.parameterValues[tweak.id, default: [:]][param.id] = .double(newVal)
                        }
                    ),
                    in: minVal...maxVal,
                    step: step
                ) { editing in
                    if !editing {
                        let latest = appState.parameterValues[tweak.id]?[param.id] ?? .double(doubleValue)
                        Task {
                            await appState.updateParameter(for: tweak, parameterID: param.id, value: latest)
                        }
                    }
                }
                .frame(maxWidth: 220)

                Text(formatDouble(doubleValue, unit: unit))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .trailing)
            }

        case .stepper(let minVal, let maxVal, let step, let unit):
            let intValue = currentValue.asInt ?? param.defaultValue.asInt ?? minVal
            Stepper(
                value: Binding(
                    get: { intValue },
                    set: { newVal in
                        Task {
                            await appState.updateParameter(for: tweak, parameterID: param.id, value: .int(newVal))
                        }
                    }
                ),
                in: minVal...maxVal,
                step: step
            ) {
                HStack {
                    Text(param.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(intValue)\(unit.map { " \($0)" } ?? "")")
                        .font(.subheadline.monospacedDigit())
                }
            }

        case .picker(let options):
            Picker(
                param.label,
                selection: Binding(
                    get: { currentValue },
                    set: { newVal in
                        Task {
                            await appState.updateParameter(for: tweak, parameterID: param.id, value: newVal)
                        }
                    }
                )
            ) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func formatDouble(_ value: Double, unit: String?) -> String {
        let formatted = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value)
        return unit.map { "\(formatted)\($0)" } ?? formatted
    }
}
