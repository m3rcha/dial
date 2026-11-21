import Foundation
import Testing
@testable import DialCore

@Suite("TweakEngine & SnapshotStore Tests")
struct TweakEngineTests {
    private static let os15 = OSVersion(major: 15, minor: 0, patch: 0)
    private static let os26 = OSVersion(major: 26, minor: 0, patch: 0)

    private func makeSampleCatalog() -> [Tweak] {
        [
            Tweak(
                id: "dock.autohide",
                name: "Auto-Hide Dock",
                description: "Automatically hide and show the Dock.",
                category: .dock,
                operations: [
                    PreferenceOperation(
                        domain: "com.apple.dock",
                        key: "autohide",
                        valueType: .bool,
                        onValue: .bool(true),
                        offValue: nil
                    )
                ],
                restartServices: [.dock]
            ),
            Tweak(
                id: "dock.autohide-delay",
                name: "Auto-Hide Delay",
                description: "Delay before Dock appears.",
                category: .dock,
                parameters: [
                    TweakParameter(
                        id: "delay",
                        label: "Delay",
                        control: .slider(min: 0, max: 2, step: 0.1, unit: "s"),
                        defaultValue: .double(0.0)
                    )
                ],
                operations: [
                    PreferenceOperation(
                        domain: "com.apple.dock",
                        key: "autohide-delay",
                        valueType: .double,
                        onValue: .double(0.0),
                        offValue: nil,
                        parameterID: "delay"
                    )
                ],
                requires: [
                    TweakPrerequisite(tweakID: "dock.autohide", expectedValue: .bool(true))
                ],
                restartServices: [.dock]
            ),
            Tweak(
                id: "dock.position-left",
                name: "Dock on Left",
                description: "Move Dock to left edge.",
                category: .dock,
                operations: [
                    PreferenceOperation(
                        domain: "com.apple.dock",
                        key: "orientation",
                        valueType: .string,
                        onValue: .string("left"),
                        offValue: .string("bottom")
                    )
                ],
                conflictsWith: ["dock.position-right"],
                restartServices: [.dock]
            ),
            Tweak(
                id: "dock.position-right",
                name: "Dock on Right",
                description: "Move Dock to right edge.",
                category: .dock,
                operations: [
                    PreferenceOperation(
                        domain: "com.apple.dock",
                        key: "orientation",
                        valueType: .string,
                        onValue: .string("right"),
                        offValue: .string("bottom")
                    )
                ],
                conflictsWith: ["dock.position-left"],
                restartServices: [.dock]
            ),
            Tweak(
                id: "glass.only-tahoe",
                name: "Tahoe Only Setting",
                description: "Requires macOS 26.",
                category: .animations,
                minOS: Self.os26,
                operations: [
                    PreferenceOperation(
                        domain: "NSGlobalDomain",
                        key: "TahoeFlag",
                        valueType: .bool,
                        onValue: .bool(true),
                        offValue: nil
                    )
                ]
            )
        ]
    }

    private func makeTempSnapshotURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("dial-test-snapshots-\(UUID().uuidString).json")
    }

    @Test("Apply records snapshot, resetToStock deletes nil offValue, revertSnapshot restores exact state")
    func applyResetAndRevert() async throws {
        let store = InMemoryPreferencesStore()
        let snapURL = makeTempSnapshotURL()
        defer { try? FileManager.default.removeItem(at: snapURL) }
        let snapshots = SnapshotStore(fileURL: snapURL)
        let engine = TweakEngine(store: store, snapshots: snapshots, currentOS: Self.os15)
        let catalog = makeSampleCatalog()

        // Initially off
        #expect(engine.isActive(catalog[0]) == false)

        // Apply dock.autohide -> true
        let services = try await engine.apply(
            selections: [SetupTweakSelection(id: "dock.autohide", enabled: true)],
            catalog: catalog,
            snapshotTitle: "Enable Auto-Hide"
        )
        #expect(services == [.dock])
        #expect(store.read(domain: "com.apple.dock", key: "autohide", byHost: false, type: .bool) == .bool(true))
        #expect(engine.isActive(catalog[0]) == true)

        // Reset to stock deletes the key because offValue == nil
        _ = try await engine.resetToStock(tweak: catalog[0])
        #expect(store.read(domain: "com.apple.dock", key: "autohide", byHost: false, type: .bool) == nil)
        #expect(engine.isActive(catalog[0]) == false)

        // Re-apply with dock.position-left (pre-existing bottom -> left), then revert snapshot
        store.write(domain: "com.apple.dock", key: "orientation", byHost: false, value: .string("bottom"))
        _ = try await engine.apply(
            selections: [SetupTweakSelection(id: "dock.position-left", enabled: true)],
            catalog: catalog,
            snapshotTitle: "Move Dock Left"
        )
        #expect(store.read(domain: "com.apple.dock", key: "orientation", byHost: false, type: .string) == .string("left"))

        let list = await snapshots.allSnapshots()
        let lastID = try #require(list.first?.id)
        _ = try await engine.revertSnapshot(id: lastID)
        #expect(store.read(domain: "com.apple.dock", key: "orientation", byHost: false, type: .string) == .string("bottom"))
    }

    @Test("previewImport classifies willChange, alreadyActive, conflict, unsupportedOS, unknown, and missing prereqs")
    func previewImportClassification() {
        let store = InMemoryPreferencesStore(initialValues: [
            PreferenceKey(domain: "com.apple.dock", key: "autohide"): .bool(true)
        ])
        let engine = TweakEngine(
            store: store,
            snapshots: SnapshotStore(fileURL: makeTempSnapshotURL()),
            currentOS: Self.os15
        )
        let catalog = makeSampleCatalog()

        let payload = SetupCodePayload(
            v: 1,
            name: "Mixed",
            tweaks: [
                SetupTweakSelection(id: "dock.autohide", enabled: true),
                SetupTweakSelection(id: "dock.position-left", enabled: true),
                SetupTweakSelection(id: "dock.position-right", enabled: true),
                SetupTweakSelection(id: "glass.only-tahoe", enabled: true),
                SetupTweakSelection(id: "community.unknown", enabled: true)
            ]
        )

        let preview = engine.previewImport(payload, catalog: catalog)
        #expect(preview.items.count == 5)
        #expect(preview.items[0].status == .alreadyActive)
        #expect(preview.items[1].status == .conflict(withIDs: ["dock.position-right"]))
        #expect(preview.items[2].status == .conflict(withIDs: ["dock.position-left"]))
        #expect(preview.items[3].status == .unsupportedOS(required: Self.os26))
        #expect(preview.items[4].status == .unknown)
    }

    @Test("DependencyResolver detects unmet prerequisite and Export My Mac captures modified tweaks")
    func prerequisitesAndExport() throws {
        let store = InMemoryPreferencesStore()
        let engine = TweakEngine(
            store: store,
            snapshots: SnapshotStore(fileURL: makeTempSnapshotURL()),
            currentOS: Self.os15
        )
        let catalog = makeSampleCatalog()

        // dock.autohide-delay requires dock.autohide = true
        let unmet = engine.unmetPrerequisites(for: catalog[1], catalog: catalog)
        #expect(unmet.map(\.tweakID) == ["dock.autohide"])

        store.write(domain: "com.apple.dock", key: "autohide", byHost: false, value: .bool(true))
        store.write(domain: "com.apple.dock", key: "autohide-delay", byHost: false, value: .double(0.2))

        #expect(engine.unmetPrerequisites(for: catalog[1], catalog: catalog).isEmpty)

        let exported = engine.exportModifiedSetup(name: "My Mac", catalog: catalog)
        #expect(exported.tweaks.count == 2)
        #expect(exported.tweaks.first(where: { $0.id == "dock.autohide-delay" })?.params?["delay"] == .double(0.2))
    }
}
