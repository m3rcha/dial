import Foundation

public struct OSVersion: Codable, Hashable, Sendable, Comparable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int = 0, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(operatingSystemVersion: OperatingSystemVersion) {
        self.major = operatingSystemVersion.majorVersion
        self.minor = operatingSystemVersion.minorVersion
        self.patch = operatingSystemVersion.patchVersion
    }

    public static func < (lhs: OSVersion, rhs: OSVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    public var formatted: String {
        patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)"
    }
}

public enum TweakCategory: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case dock = "Dock"
    case finder = "Finder"
    case windowManagement = "Window & Mission Control"
    case screenshots = "Screenshots"
    case keyboard = "Keyboard & Input"
    case trackpadMouse = "Trackpad & Mouse"
    case menuBarDesktop = "Menu Bar & Desktop"
    case animations = "Animations & Performance"
    case developerPrivacy = "Developer & Privacy"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .dock: return "dock.rectangle"
        case .finder: return "folder"
        case .windowManagement: return "macwindow.on.rectangle"
        case .screenshots: return "camera.viewfinder"
        case .keyboard: return "keyboard"
        case .trackpadMouse: return "computermouse"
        case .menuBarDesktop: return "menubar.rectangle"
        case .animations: return "gauge.with.dots.needle.67percent"
        case .developerPrivacy: return "hammer"
        }
    }
}

public enum RiskLevel: String, Codable, Hashable, Sendable {
    case safe
    case moderate
    case advanced
}

public enum TweakSource: String, Codable, Hashable, Sendable {
    case builtIn = "built-in"
    case community
}

public enum AllowlistedService: String, Codable, Hashable, Sendable, CaseIterable {
    case dock = "Dock"
    case finder = "Finder"
    case systemUIServer = "SystemUIServer"
    case controlCenter = "ControlCenter"
    case windowManager = "WindowManager"
    case cfprefsd = "cfprefsd"

    public var processName: String { rawValue }
}

public enum TweakValueType: String, Codable, Hashable, Sendable {
    case bool
    case int
    case double
    case string
}

/// Type-safe primitive preference value that strictly distinguishes Bool from Int in JSON.
public enum TweakValue: Hashable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    public var displayString: String {
        switch self {
        case .bool(let v): return v ? "On" : "Off"
        case .int(let v): return String(v)
        case .double(let v):
            return v.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", v)
                : String(format: "%.2g", v)
        case .string(let v): return v
        }
    }

    public var asBool: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    public var asInt: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    public var asDouble: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return nil
        }
    }

    public var asString: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    public func normalized(for type: TweakValueType) -> TweakValue {
        switch (type, self) {
        case (.double, .int(let i)): return .double(Double(i))
        case (.int, .double(let d)) where d.truncatingRemainder(dividingBy: 1) == 0:
            return .int(Int(d))
        default: return self
        }
    }
}

extension TweakValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Check Bool before Int/Double so JSON true/false never decode as 1/0.
        if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else {
            throw DecodingError.typeMismatch(
                TweakValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Bool, Int, Double, or String for TweakValue"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }
}

public struct ParameterOption: Codable, Hashable, Sendable {
    public let label: String
    public let value: TweakValue

    public init(label: String, value: TweakValue) {
        self.label = label
        self.value = value
    }
}

public enum ParameterControl: Codable, Hashable, Sendable {
    case slider(min: Double, max: Double, step: Double, unit: String?)
    case stepper(min: Int, max: Int, step: Int, unit: String?)
    case picker(options: [ParameterOption])

    private enum CodingKeys: String, CodingKey {
        case kind, min, max, step, unit, options
    }

    private enum Kind: String, Codable {
        case slider, stepper, picker
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .slider:
            self = .slider(
                min: try c.decode(Double.self, forKey: .min),
                max: try c.decode(Double.self, forKey: .max),
                step: try c.decode(Double.self, forKey: .step),
                unit: try c.decodeIfPresent(String.self, forKey: .unit)
            )
        case .stepper:
            self = .stepper(
                min: try c.decode(Int.self, forKey: .min),
                max: try c.decode(Int.self, forKey: .max),
                step: try c.decode(Int.self, forKey: .step),
                unit: try c.decodeIfPresent(String.self, forKey: .unit)
            )
        case .picker:
            self = .picker(options: try c.decode([ParameterOption].self, forKey: .options))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .slider(let min, let max, let step, let unit):
            try c.encode(Kind.slider, forKey: .kind)
            try c.encode(min, forKey: .min)
            try c.encode(max, forKey: .max)
            try c.encode(step, forKey: .step)
            try c.encodeIfPresent(unit, forKey: .unit)
        case .stepper(let min, let max, let step, let unit):
            try c.encode(Kind.stepper, forKey: .kind)
            try c.encode(min, forKey: .min)
            try c.encode(max, forKey: .max)
            try c.encode(step, forKey: .step)
            try c.encodeIfPresent(unit, forKey: .unit)
        case .picker(let options):
            try c.encode(Kind.picker, forKey: .kind)
            try c.encode(options, forKey: .options)
        }
    }
}

public struct TweakParameter: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let control: ParameterControl
    public let defaultValue: TweakValue

    private enum CodingKeys: String, CodingKey {
        case id, label, control, defaultValue
    }

    public init(id: String, label: String, control: ParameterControl, defaultValue: TweakValue) {
        self.id = id
        self.label = label
        self.control = control
        self.defaultValue = defaultValue
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        control = try c.decode(ParameterControl.self, forKey: .control)
        let rawDefault = try c.decode(TweakValue.self, forKey: .defaultValue)
        switch control {
        case .slider:
            defaultValue = rawDefault.normalized(for: .double)
        case .stepper:
            defaultValue = rawDefault.normalized(for: .int)
        case .picker:
            defaultValue = rawDefault
        }
    }
}

public struct PreferenceOperation: Codable, Hashable, Sendable {
    public let domain: String
    public let key: String
    public let byHost: Bool
    public let valueType: TweakValueType
    public let onValue: TweakValue
    public let offValue: TweakValue?
    public let parameterID: String?

    private enum CodingKeys: String, CodingKey {
        case domain, key, byHost, valueType, onValue, offValue, parameterID
    }

    public init(
        domain: String,
        key: String,
        byHost: Bool = false,
        valueType: TweakValueType,
        onValue: TweakValue,
        offValue: TweakValue? = nil,
        parameterID: String? = nil
    ) {
        self.domain = domain
        self.key = key
        self.byHost = byHost
        self.valueType = valueType
        self.onValue = onValue
        self.offValue = offValue
        self.parameterID = parameterID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        domain = try c.decode(String.self, forKey: .domain)
        key = try c.decode(String.self, forKey: .key)
        byHost = try c.decodeIfPresent(Bool.self, forKey: .byHost) ?? false
        valueType = try c.decode(TweakValueType.self, forKey: .valueType)
        onValue = try c.decode(TweakValue.self, forKey: .onValue).normalized(for: valueType)
        offValue = try c.decodeIfPresent(TweakValue.self, forKey: .offValue)?.normalized(for: valueType)
        parameterID = try c.decodeIfPresent(String.self, forKey: .parameterID)
    }
}

public struct TweakPrerequisite: Codable, Hashable, Sendable {
    public let tweakID: String
    public let expectedValue: TweakValue

    public init(tweakID: String, expectedValue: TweakValue) {
        self.tweakID = tweakID
        self.expectedValue = expectedValue
    }
}

public struct Tweak: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let category: TweakCategory
    public let keywords: [String]
    public let minOS: OSVersion?
    public let maxOS: OSVersion?
    public let osNote: String?
    public let riskLevel: RiskLevel
    public let parameters: [TweakParameter]?
    public let operations: [PreferenceOperation]
    public let requires: [TweakPrerequisite]?
    public let conflictsWith: [String]?
    public let restartServices: [AllowlistedService]
    public var source: TweakSource

    private enum CodingKeys: String, CodingKey {
        case id, name, description, category, keywords, minOS, maxOS, osNote, riskLevel,
             parameters, operations, requires, conflictsWith, restartServices, source
    }

    public init(
        id: String,
        name: String,
        description: String,
        category: TweakCategory,
        keywords: [String] = [],
        minOS: OSVersion? = nil,
        maxOS: OSVersion? = nil,
        osNote: String? = nil,
        riskLevel: RiskLevel = .safe,
        parameters: [TweakParameter]? = nil,
        operations: [PreferenceOperation],
        requires: [TweakPrerequisite]? = nil,
        conflictsWith: [String]? = nil,
        restartServices: [AllowlistedService] = [],
        source: TweakSource = .builtIn
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.keywords = keywords
        self.minOS = minOS
        self.maxOS = maxOS
        self.osNote = osNote
        self.riskLevel = riskLevel
        self.parameters = parameters
        self.operations = operations
        self.requires = requires
        self.conflictsWith = conflictsWith
        self.restartServices = restartServices
        self.source = source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decode(String.self, forKey: .description)
        category = try c.decode(TweakCategory.self, forKey: .category)
        keywords = try c.decodeIfPresent([String].self, forKey: .keywords) ?? []
        minOS = try c.decodeIfPresent(OSVersion.self, forKey: .minOS)
        maxOS = try c.decodeIfPresent(OSVersion.self, forKey: .maxOS)
        osNote = try c.decodeIfPresent(String.self, forKey: .osNote)
        riskLevel = try c.decodeIfPresent(RiskLevel.self, forKey: .riskLevel) ?? .safe
        parameters = try c.decodeIfPresent([TweakParameter].self, forKey: .parameters)
        operations = try c.decode([PreferenceOperation].self, forKey: .operations)
        requires = try c.decodeIfPresent([TweakPrerequisite].self, forKey: .requires)
        conflictsWith = try c.decodeIfPresent([String].self, forKey: .conflictsWith)
        restartServices = try c.decodeIfPresent([AllowlistedService].self, forKey: .restartServices) ?? []
        source = try c.decodeIfPresent(TweakSource.self, forKey: .source) ?? .builtIn
    }

    public func isSupported(on os: OSVersion) -> Bool {
        if let minOS, os < minOS { return false }
        if let maxOS, os > maxOS { return false }
        return true
    }
}
