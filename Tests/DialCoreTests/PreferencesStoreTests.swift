import Foundation
import Testing
@testable import DialCore

@Suite("PreferencesStore Tests")
struct PreferencesStoreTests {
    @Test("Read, write, delete, and byHost isolation")
    func readWriteDeleteAndByHost() {
        let store = InMemoryPreferencesStore()

        #expect(store.read(domain: "com.apple.dock", key: "autohide", byHost: false, type: .bool) == nil)

        store.write(domain: "com.apple.dock", key: "autohide", byHost: false, value: .bool(true))
        #expect(store.read(domain: "com.apple.dock", key: "autohide", byHost: false, type: .bool) == .bool(true))
        #expect(store.read(domain: "com.apple.dock", key: "autohide", byHost: true, type: .bool) == nil)

        store.write(domain: "com.apple.dock", key: "autohide", byHost: false, value: nil)
        #expect(store.read(domain: "com.apple.dock", key: "autohide", byHost: false, type: .bool) == nil)
    }

    @Test("Preserves strict Bool vs Int distinction")
    func boolVsInt() {
        let store = InMemoryPreferencesStore()

        store.write(domain: "com.apple.finder", key: "BoolKey", byHost: false, value: .bool(true))
        store.write(domain: "com.apple.finder", key: "IntKey", byHost: false, value: .int(1))

        #expect(store.read(domain: "com.apple.finder", key: "BoolKey", byHost: false, type: .bool) == .bool(true))
        #expect(store.read(domain: "com.apple.finder", key: "IntKey", byHost: false, type: .int) == .int(1))
        #expect(store.read(domain: "com.apple.finder", key: "BoolKey", byHost: false, type: .int) == nil)
        #expect(store.read(domain: "com.apple.finder", key: "IntKey", byHost: false, type: .bool) == nil)
    }
}
