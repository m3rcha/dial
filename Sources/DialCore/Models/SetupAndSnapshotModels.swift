import Foundation

public struct SetupTweakSelection: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public var enabled: Bool
    public var params: [String: TweakValue]?

    public init(id: String, enabled: Bool = true, params: [String: TweakValue]? = nil) {
        self.id = id
        self.enabled = enabled
        self.params = params
    }
}

public struct SetupCodePayload: Codable, Hashable, Sendable {
    public let v: Int
    public let name: String
    public let tweaks: [SetupTweakSelection]

    public init(v: Int = 1, name: String, tweaks: [SetupTweakSelection]) {
        self.v = v
        self.name = name
        self.tweaks = tweaks
    }
}

public struct RecordedChange: Codable, Hashable, Sendable {
    public let domain: String
    public let key: String
    public let byHost: Bool
    public let valueType: TweakValueType
    public let previousValue: TweakValue?
    public let newValue: TweakValue?

    public init(
        domain: String,
        key: String,
        byHost: Bool,
        valueType: TweakValueType,
        previousValue: TweakValue?,
        newValue: TweakValue?
    ) {
        self.domain = domain
        self.key = key
        self.byHost = byHost
        self.valueType = valueType
        self.previousValue = previousValue
        self.newValue = newValue
    }
}

public struct SnapshotEntry: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let changes: [RecordedChange]
    public let services: [AllowlistedService]

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        changes: [RecordedChange],
        services: [AllowlistedService] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.changes = changes
        self.services = services
    }
}

public struct Profile: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let symbolName: String
    public let isBuiltIn: Bool
    public let selections: [SetupTweakSelection]

    public init(
        id: String,
        name: String,
        description: String,
        symbolName: String,
        isBuiltIn: Bool = false,
        selections: [SetupTweakSelection]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.symbolName = symbolName
        self.isBuiltIn = isBuiltIn
        self.selections = selections
    }
}

public struct CommunityFeedEnvelope: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let updatedAt: String
    public let tweaks: [Tweak]

    public init(schemaVersion: Int, updatedAt: String, tweaks: [Tweak]) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.tweaks = tweaks
    }
}
