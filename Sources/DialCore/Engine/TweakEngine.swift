import Foundation

public enum ImportItemStatus: Hashable, Sendable {
    case willChange
    case alreadyActive
    case conflict(withIDs: [String])
    case unsupportedOS(required: OSVersion)
    case unknown
}

public struct ImportPreviewItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let selection: SetupTweakSelection
    public let tweak: Tweak?
    public let status: ImportItemStatus
    public let currentSummary: String
    public let targetSummary: String
    public let missingPrerequisites: [TweakPrerequisite]

    public init(
        id: String,
        selection: SetupTweakSelection,
        tweak: Tweak?,
        status: ImportItemStatus,
        currentSummary: String,
        targetSummary: String,
        missingPrerequisites: [TweakPrerequisite] = []
    ) {
        self.id = id
        self.selection = selection
        self.tweak = tweak
        self.status = status
        self.currentSummary = currentSummary
        self.targetSummary = targetSummary
        self.missingPrerequisites = missingPrerequisites
    }

    public var isSelectable: Bool {
        switch status {
        case .willChange, .conflict: return true
        case .alreadyActive, .unsupportedOS, .unknown: return false
        }
    }
}

public struct ImportPreview: Hashable, Sendable {
    public let name: String
    public let items: [ImportPreviewItem]

    public init(name: String, items: [ImportPreviewItem]) {
        self.name = name
        self.items = items
    }
}

public enum TweakEngineError: Error, LocalizedError, Sendable {
    case snapshotNotFound
    case unsupportedOS(tweakID: String, required: OSVersion)

    public var errorDescription: String? {
        switch self {
        case .snapshotNotFound:
            return "The requested snapshot could not be found."
        case .unsupportedOS(let id, let required):
            return "\(id) requires macOS \(required.formatted) or newer."
        }
    }
}

public final class TweakEngine: Sendable {
    public let store: PreferencesStore
    public let snapshots: SnapshotStore
    public let currentOS: OSVersion

    public init(
        store: PreferencesStore = CFPreferencesStore(),
        snapshots: SnapshotStore = SnapshotStore(),
        currentOS: OSVersion = OSVersion(operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersion)
    ) {
        self.store = store
        self.snapshots = snapshots
        self.currentOS = currentOS
    }

    // MARK: - Live State Reading

    public func isActive(_ tweak: Tweak) -> Bool {
        guard !tweak.operations.isEmpty else { return false }
        for op in tweak.operations {
            let current = store.read(domain: op.domain, key: op.key, byHost: op.byHost, type: op.valueType)
            if op.parameterID != nil {
                // Parameterized op is active if a non-nil value is set (and differs from offValue if defined)
                if let current {
                    if let off = op.offValue, current == off {
                        return false
                    }
                    continue
                } else {
                    return false
                }
            } else {
                guard let current, current == op.onValue else {
                    return false
                }
            }
        }
        return true
    }

    public func currentParameterValues(for tweak: Tweak) -> [String: TweakValue] {
        guard let params = tweak.parameters else { return [:] }
        var result: [String: TweakValue] = [:]
        for param in params {
            if let op = tweak.operations.first(where: { $0.parameterID == param.id }),
               let live = store.read(domain: op.domain, key: op.key, byHost: op.byHost, type: op.valueType) {
                result[param.id] = live.normalized(for: op.valueType)
            } else {
                result[param.id] = param.defaultValue
            }
        }
        return result
    }

    public func isModifiedFromStock(_ tweak: Tweak) -> Bool {
        if isActive(tweak) { return true }
        for op in tweak.operations {
            if let current = store.read(domain: op.domain, key: op.key, byHost: op.byHost, type: op.valueType) {
                if let off = op.offValue, current == off {
                    continue
                }
                return true
            }
        }
        return false
    }

    // MARK: - Dependencies & Conflicts

    public func unmetPrerequisites(for tweak: Tweak, catalog: [Tweak]) -> [TweakPrerequisite] {
        guard let requires = tweak.requires, !requires.isEmpty else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        return requires.filter { req in
            guard let target = byID[req.tweakID] else { return true }
            if req.expectedValue == .bool(true) {
                return !isActive(target)
            }
            guard let firstOp = target.operations.first else { return true }
            let live = store.read(domain: firstOp.domain, key: firstOp.key, byHost: firstOp.byHost, type: firstOp.valueType)
            return live != req.expectedValue
        }
    }

    // MARK: - Export My Mac

    public func exportModifiedSetup(name: String, catalog: [Tweak]) -> SetupCodePayload {
        var selections: [SetupTweakSelection] = []
        for tweak in catalog where tweak.isSupported(on: currentOS) {
            if isActive(tweak) {
                let paramVals = currentParameterValues(for: tweak)
                selections.append(
                    SetupTweakSelection(
                        id: tweak.id,
                        enabled: true,
                        params: paramVals.isEmpty ? nil : paramVals
                    )
                )
            }
        }
        return SetupCodePayload(v: 1, name: name, tweaks: selections)
    }

    // MARK: - Preview Import

    public func previewImport(_ payload: SetupCodePayload, catalog: [Tweak]) -> ImportPreview {
        let byID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        let enabledIDs = Set(payload.tweaks.filter(\.enabled).map(\.id))

        let items: [ImportPreviewItem] = payload.tweaks.map { selection in
            guard let tweak = byID[selection.id] else {
                return ImportPreviewItem(
                    id: selection.id,
                    selection: selection,
                    tweak: nil,
                    status: .unknown,
                    currentSummary: "Unknown",
                    targetSummary: selection.enabled ? "On" : "Off"
                )
            }

            if !tweak.isSupported(on: currentOS) {
                let required = tweak.minOS ?? OSVersion(major: 15, minor: 0, patch: 0)
                return ImportPreviewItem(
                    id: selection.id,
                    selection: selection,
                    tweak: tweak,
                    status: .unsupportedOS(required: required),
                    currentSummary: isActive(tweak) ? "On" : "Off",
                    targetSummary: selection.enabled ? "On" : "Off"
                )
            }

            // Conflict check within enabled selections
            var conflicts: [String] = []
            if selection.enabled, let declaredConflicts = tweak.conflictsWith {
                conflicts.append(contentsOf: declaredConflicts.filter { enabledIDs.contains($0) })
            }
            for other in payload.tweaks where other.enabled && other.id != selection.id {
                if let otherTweak = byID[other.id],
                   let otherConflicts = otherTweak.conflictsWith,
                   otherConflicts.contains(selection.id),
                   !conflicts.contains(other.id) {
                    conflicts.append(other.id)
                }
            }

            let currentSummary = describeCurrent(tweak: tweak)
            let targetSummary = describeTarget(tweak: tweak, selection: selection)

            if !conflicts.isEmpty {
                return ImportPreviewItem(
                    id: selection.id,
                    selection: selection,
                    tweak: tweak,
                    status: .conflict(withIDs: conflicts),
                    currentSummary: currentSummary,
                    targetSummary: targetSummary
                )
            }

            let missing = selection.enabled
                ? unmetPrerequisites(for: tweak, catalog: catalog).filter { !enabledIDs.contains($0.tweakID) }
                : []

            let alreadyMatches = matchesTarget(tweak: tweak, selection: selection)
            return ImportPreviewItem(
                id: selection.id,
                selection: selection,
                tweak: tweak,
                status: alreadyMatches ? .alreadyActive : .willChange,
                currentSummary: currentSummary,
                targetSummary: targetSummary,
                missingPrerequisites: missing
            )
        }

        return ImportPreview(name: payload.name, items: items)
    }

    // MARK: - Apply & Rollback

    @discardableResult
    public func apply(
        selections: [SetupTweakSelection],
        catalog: [Tweak],
        snapshotTitle: String
    ) async throws -> Set<AllowlistedService> {
        let byID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        var recordedChanges: [RecordedChange] = []
        var affectedServices: Set<AllowlistedService> = []

        for selection in selections {
            guard let tweak = byID[selection.id], tweak.isSupported(on: currentOS) else {
                continue
            }

            for op in tweak.operations {
                let previous = store.read(domain: op.domain, key: op.key, byHost: op.byHost, type: op.valueType)
                let newValue: TweakValue?
                if selection.enabled {
                    if let paramID = op.parameterID,
                       let override = selection.params?[paramID] {
                        newValue = override.normalized(for: op.valueType)
                    } else {
                        newValue = op.onValue.normalized(for: op.valueType)
                    }
                } else {
                    newValue = op.offValue?.normalized(for: op.valueType)
                }

                if previous != newValue {
                    store.write(domain: op.domain, key: op.key, byHost: op.byHost, value: newValue)
                    recordedChanges.append(
                        RecordedChange(
                            domain: op.domain,
                            key: op.key,
                            byHost: op.byHost,
                            valueType: op.valueType,
                            previousValue: previous,
                            newValue: newValue
                        )
                    )
                }
            }

            affectedServices.formUnion(tweak.restartServices)
        }

        if !recordedChanges.isEmpty {
            let entry = SnapshotEntry(
                title: snapshotTitle,
                changes: recordedChanges,
                services: Array(affectedServices)
            )
            try await snapshots.record(entry)
        }

        return affectedServices
    }

    @discardableResult
    public func resetToStock(tweak: Tweak) async throws -> Set<AllowlistedService> {
        try await apply(
            selections: [SetupTweakSelection(id: tweak.id, enabled: false)],
            catalog: [tweak],
            snapshotTitle: "Reset \(tweak.name)"
        )
    }

    @discardableResult
    public func revertSnapshot(id: UUID) async throws -> Set<AllowlistedService> {
        let all = await snapshots.allSnapshots()
        guard let entry = all.first(where: { $0.id == id }) else {
            throw TweakEngineError.snapshotNotFound
        }

        for change in entry.changes.reversed() {
            store.write(
                domain: change.domain,
                key: change.key,
                byHost: change.byHost,
                value: change.previousValue
            )
        }

        try await snapshots.remove(id: id)
        return Set(entry.services)
    }

    // MARK: - Helpers

    private func matchesTarget(tweak: Tweak, selection: SetupTweakSelection) -> Bool {
        for op in tweak.operations {
            let live = store.read(domain: op.domain, key: op.key, byHost: op.byHost, type: op.valueType)
            let expected: TweakValue?
            if selection.enabled {
                if let paramID = op.parameterID, let override = selection.params?[paramID] {
                    expected = override.normalized(for: op.valueType)
                } else {
                    expected = op.onValue.normalized(for: op.valueType)
                }
            } else {
                expected = op.offValue?.normalized(for: op.valueType)
            }
            if live != expected {
                return false
            }
        }
        return true
    }

    private func describeCurrent(tweak: Tweak) -> String {
        guard let first = tweak.operations.first else { return "—" }
        let live = store.read(domain: first.domain, key: first.key, byHost: first.byHost, type: first.valueType)
        return live?.displayString ?? "Stock"
    }

    private func describeTarget(tweak: Tweak, selection: SetupTweakSelection) -> String {
        if !selection.enabled {
            return tweak.operations.first?.offValue?.displayString ?? "Stock"
        }
        if let firstParam = tweak.parameters?.first,
           let val = selection.params?[firstParam.id] {
            return val.displayString
        }
        return tweak.operations.first?.onValue.displayString ?? "On"
    }
}
