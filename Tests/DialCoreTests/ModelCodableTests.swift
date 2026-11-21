import Foundation
import Testing
@testable import DialCore

@Suite("Model Codable Tests")
struct ModelCodableTests {
    @Test("Tweak preserves bool vs int values and parameter controls")
    func tweakRoundTrip() throws {
        let tweak = Tweak(
            id: "dock.autohide-delay",
            name: "Dock Auto-Hide Delay",
            description: "Adjust delay before Dock appears.",
            category: .dock,
            keywords: ["dock", "autohide-delay"],
            minOS: OSVersion(major: 15, minor: 0, patch: 0),
            maxOS: nil,
            osNote: nil,
            riskLevel: .safe,
            parameters: [
                TweakParameter(
                    id: "delay",
                    label: "Delay",
                    control: .slider(min: 0.0, max: 2.0, step: 0.1, unit: "s"),
                    defaultValue: .double(0.0)
                ),
                TweakParameter(
                    id: "mode",
                    label: "Mode",
                    control: .picker(options: [
                        ParameterOption(label: "Fast", value: .int(1)),
                        ParameterOption(label: "Default", value: .bool(true))
                    ]),
                    defaultValue: .int(1)
                )
            ],
            operations: [
                PreferenceOperation(
                    domain: "com.apple.dock",
                    key: "autohide-delay",
                    byHost: false,
                    valueType: .double,
                    onValue: .double(0.0),
                    offValue: nil,
                    parameterID: "delay"
                )
            ],
            requires: [
                TweakPrerequisite(tweakID: "dock.autohide", expectedValue: .bool(true))
            ],
            conflictsWith: [],
            restartServices: [.dock],
            source: .builtIn
        )

        let data = try JSONEncoder().encode(tweak)
        let decoded = try JSONDecoder().decode(Tweak.self, from: data)
        #expect(decoded == tweak)
        #expect(decoded.parameters?[1].control == .picker(options: [
            ParameterOption(label: "Fast", value: .int(1)),
            ParameterOption(label: "Default", value: .bool(true))
        ]))
    }

    @Test("SetupCodePayload and CommunityFeedEnvelope encode and decode")
    func setupAndFeedRoundTrip() throws {
        let payload = SetupCodePayload(
            v: 1,
            name: "Minimal Dev",
            tweaks: [
                SetupTweakSelection(
                    id: "dock.autohide",
                    enabled: true,
                    params: ["delay": .double(0.1)]
                ),
                SetupTweakSelection(
                    id: "dock.show-recents",
                    enabled: false,
                    params: nil
                )
            ]
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(SetupCodePayload.self, from: data)
        #expect(decoded == payload)

        let envelope = CommunityFeedEnvelope(
            schemaVersion: 1,
            updatedAt: "2026-11-22T00:00:00Z",
            tweaks: []
        )
        let envData = try JSONEncoder().encode(envelope)
        let decodedEnv = try JSONDecoder().decode(CommunityFeedEnvelope.self, from: envData)
        #expect(decodedEnv == envelope)
    }
}
