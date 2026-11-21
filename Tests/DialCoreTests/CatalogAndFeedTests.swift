import Foundation
import Testing
@testable import DialCore

@Suite("Catalog & CommunityFeed Tests")
struct CatalogAndFeedTests {
    @Test("Bundled catalog has 50+ unique, valid, non-TCC tweaks")
    func bundledCatalogIntegrity() throws {
        let tweaks = try CatalogLoader.loadBundledCatalog()
        #expect(tweaks.count >= 50)

        let ids = Set(tweaks.map(\.id))
        #expect(ids.count == tweaks.count)

        let blockedDomains: Set<String> = ["com.apple.Safari"]
        for tweak in tweaks {
            #expect(!tweak.operations.isEmpty)
            for op in tweak.operations {
                #expect(!blockedDomains.contains(op.domain))
                if let paramID = op.parameterID {
                    let paramExists = tweak.parameters?.contains(where: { $0.id == paramID }) ?? false
                    #expect(paramExists)
                }
            }
            for req in tweak.requires ?? [] {
                #expect(ids.contains(req.tweakID))
            }
            for conflict in tweak.conflictsWith ?? [] {
                #expect(ids.contains(conflict))
            }
        }

        // All 9 categories should have at least 3 tweaks
        for category in TweakCategory.allCases {
            let count = tweaks.filter { $0.category == category }.count
            #expect(count >= 3)
        }
    }

    @Test("CommunityFeedClient rejects non-HTTPS URLs and unsupported schemaVersion")
    func communityFeedValidation() throws {
        #expect(CommunityFeedClient.validateFeedURL("http://example.com/feed.json") == false)
        #expect(CommunityFeedClient.validateFeedURL("https://raw.githubusercontent.com/m3rcha/dial-registry/main/feed.json") == true)

        let v2JSON = """
        {
          "schemaVersion": 2,
          "updatedAt": "2026-11-22T00:00:00Z",
          "tweaks": []
        }
        """.data(using: .utf8)!

        #expect(throws: CommunityFeedError.unsupportedSchemaVersion(2)) {
            try CommunityFeedClient.decodeFeed(data: v2JSON)
        }
    }
}
