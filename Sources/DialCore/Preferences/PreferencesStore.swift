import CoreFoundation
import Foundation

public struct PreferenceKey: Hashable, Sendable {
    public let domain: String
    public let key: String
    public let byHost: Bool

    public init(domain: String, key: String, byHost: Bool = false) {
        self.domain = domain
        self.key = key
        self.byHost = byHost
    }
}

public protocol PreferencesStore: Sendable {
    func read(domain: String, key: String, byHost: Bool, type: TweakValueType) -> TweakValue?
    func write(domain: String, key: String, byHost: Bool, value: TweakValue?)
    func synchronize(domain: String, byHost: Bool)
}

public final class InMemoryPreferencesStore: PreferencesStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [PreferenceKey: TweakValue] = [:]

    public init(initialValues: [PreferenceKey: TweakValue] = [:]) {
        self.storage = initialValues
    }

    public func read(domain: String, key: String, byHost: Bool, type: TweakValueType) -> TweakValue? {
        lock.lock()
        defer { lock.unlock() }
        guard let value = storage[PreferenceKey(domain: domain, key: key, byHost: byHost)] else {
            return nil
        }
        switch (type, value) {
        case (.bool, .bool): return value
        case (.int, .int): return value
        case (.double, .double): return value
        case (.double, .int(let i)): return .double(Double(i))
        case (.string, .string): return value
        default: return nil
        }
    }

    public func write(domain: String, key: String, byHost: Bool, value: TweakValue?) {
        lock.lock()
        defer { lock.unlock() }
        let prefKey = PreferenceKey(domain: domain, key: key, byHost: byHost)
        if let value {
            storage[prefKey] = value
        } else {
            storage.removeValue(forKey: prefKey)
        }
    }

    public func synchronize(domain: String, byHost: Bool) {}

    public func snapshotAll() -> [PreferenceKey: TweakValue] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

public struct CFPreferencesStore: PreferencesStore {
    public init() {}

    public func read(domain: String, key: String, byHost: Bool, type: TweakValueType) -> TweakValue? {
        let appID = cfAppID(for: domain)
        let host = byHost ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost
        CFPreferencesSynchronize(appID, kCFPreferencesCurrentUser, host)
        guard let raw = CFPreferencesCopyValue(key as CFString, appID, kCFPreferencesCurrentUser, host) else {
            return nil
        }

        switch type {
        case .bool:
            if CFGetTypeID(raw) == CFBooleanGetTypeID(), let boolVal = raw as? Bool {
                return .bool(boolVal)
            }
            if let number = raw as? NSNumber {
                return .bool(number.intValue != 0)
            }
            return nil
        case .int:
            if CFGetTypeID(raw) != CFBooleanGetTypeID(), let number = raw as? NSNumber {
                return .int(number.intValue)
            }
            return nil
        case .double:
            if CFGetTypeID(raw) != CFBooleanGetTypeID(), let number = raw as? NSNumber {
                return .double(number.doubleValue)
            }
            return nil
        case .string:
            if let str = raw as? String {
                return .string(str)
            }
            return nil
        }
    }

    public func write(domain: String, key: String, byHost: Bool, value: TweakValue?) {
        let appID = cfAppID(for: domain)
        let host = byHost ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost
        let cfValue: CFPropertyList? = switch value {
        case .some(.bool(let v)): v as CFBoolean
        case .some(.int(let v)): NSNumber(value: v)
        case .some(.double(let v)): NSNumber(value: v)
        case .some(.string(let v)): v as CFString
        case .none: nil
        }
        CFPreferencesSetValue(key as CFString, cfValue, appID, kCFPreferencesCurrentUser, host)
        CFPreferencesSynchronize(appID, kCFPreferencesCurrentUser, host)
    }

    public func synchronize(domain: String, byHost: Bool) {
        let appID = cfAppID(for: domain)
        let host = byHost ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost
        CFPreferencesSynchronize(appID, kCFPreferencesCurrentUser, host)
    }

    private func cfAppID(for domain: String) -> CFString {
        domain == "NSGlobalDomain" ? kCFPreferencesAnyApplication : (domain as CFString)
    }
}
