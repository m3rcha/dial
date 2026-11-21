import Foundation
import Testing
@testable import DialCore

@Suite("SetupCodeCodec Tests")
struct SetupCodeCodecTests {
    @Test("Round-trip encode and decode preserves selections and params")
    func roundTrip() throws {
        let payload = SetupCodePayload(
            v: 1,
            name: "Clean Dev",
            tweaks: [
                SetupTweakSelection(id: "dock.autohide", enabled: true),
                SetupTweakSelection(
                    id: "dock.autohide-delay",
                    enabled: true,
                    params: ["delay": .double(0.0)]
                ),
                SetupTweakSelection(id: "dock.show-recents", enabled: false)
            ]
        )

        let code = try SetupCodeCodec.encode(payload)
        #expect(code.hasPrefix("dial:v1:"))
        #expect(!code.contains("="))
        #expect(!code.contains("+"))
        #expect(!code.contains("/"))

        let decoded = try SetupCodeCodec.decode(code)
        #expect(decoded.v == 1)
        #expect(decoded.name == "Clean Dev")
        #expect(decoded.tweaks.count == 3)
        #expect(decoded.tweaks[1].params?["delay"] == .double(0.0) || decoded.tweaks[1].params?["delay"] == .int(0))
        #expect(decoded.tweaks[2].enabled == false)
    }

    @Test("Deep link generation and extraction")
    func deepLinkRoundTrip() throws {
        let payload = SetupCodePayload(v: 1, name: "Quick", tweaks: [
            SetupTweakSelection(id: "finder.show-hidden-files", enabled: true)
        ])
        let code = try SetupCodeCodec.encode(payload)
        let url = try #require(SetupCodeCodec.deepLinkURL(for: code))
        #expect(url.scheme == "dial")
        #expect(url.host == "import")
        let extracted = SetupCodeCodec.extractCode(from: url)
        #expect(extracted == code)
    }

    @Test("Rejects invalid prefix, corrupted base64url, truncated zlib, and unsupported version")
    func errorHandling() throws {
        #expect(throws: SetupCodeError.invalidPrefix) {
            try SetupCodeCodec.decode("baremac:v1:abc")
        }
        #expect(throws: SetupCodeError.invalidBase64) {
            try SetupCodeCodec.decode("dial:v1:%%%notbase64%%%")
        }
        #expect(throws: SetupCodeError.decompressionFailed) {
            try SetupCodeCodec.decode("dial:v1:eJzT")
        }

        // Valid zlib-compressed JSON with v: 2
        let v2Code = try SetupCodeCodec.encode(SetupCodePayload(v: 2, name: "Future", tweaks: []))
        #expect(throws: SetupCodeError.unsupportedVersion(2)) {
            try SetupCodeCodec.decode(v2Code)
        }
    }
}
