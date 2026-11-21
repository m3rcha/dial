import Foundation

public enum CommunityFeedError: Error, LocalizedError, Equatable, Sendable {
    case invalidURL
    case insecureURL
    case networkFailure(String)
    case invalidResponse
    case unsupportedSchemaVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The community feed URL is invalid."
        case .insecureURL:
            return "Community feed URLs must use HTTPS."
        case .networkFailure(let message):
            return "Could not fetch community tweaks: \(message)"
        case .invalidResponse:
            return "Community feed response is not valid Dial JSON."
        case .unsupportedSchemaVersion(let version):
            return "Community feed schema v\(version) requires a newer version of Dial."
        }
    }
}

public actor CommunityFeedClient {
    public static let defaultFeedURLString = "https://raw.githubusercontent.com/m3rcha/dial-registry/main/feed.json"
    public static let supportedSchemaVersion = 1

    private let cacheURL: URL
    private let session: URLSession

    public init(cacheURL: URL? = nil, session: URLSession = .shared) {
        if let cacheURL {
            self.cacheURL = cacheURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.cacheURL = appSupport
                .appendingPathComponent("Dial", isDirectory: true)
                .appendingPathComponent("community-cache.json")
        }
        self.session = session
    }

    public static func validateFeedURL(_ raw: String) -> Bool {
        guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              let host = url.host,
              !host.isEmpty else {
            return false
        }
        return true
    }

    public static func decodeFeed(data: Data) throws -> [Tweak] {
        let envelope: CommunityFeedEnvelope
        do {
            envelope = try JSONDecoder().decode(CommunityFeedEnvelope.self, from: data)
        } catch {
            throw CommunityFeedError.invalidResponse
        }

        guard envelope.schemaVersion == supportedSchemaVersion else {
            throw CommunityFeedError.unsupportedSchemaVersion(envelope.schemaVersion)
        }

        return envelope.tweaks.map { tweak in
            var copy = tweak
            copy.source = .community
            return copy
        }
    }

    public func loadCachedTweaks() -> [Tweak] {
        guard let data = try? Data(contentsOf: cacheURL),
              let tweaks = try? Self.decodeFeed(data: data) else {
            return []
        }
        return tweaks
    }

    public func fetch(from urlString: String) async throws -> [Tweak] {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw CommunityFeedError.invalidURL
        }
        guard url.scheme?.lowercased() == "https", url.host != nil else {
            throw CommunityFeedError.insecureURL
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw CommunityFeedError.networkFailure(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw CommunityFeedError.networkFailure("HTTP \(http.statusCode)")
        }

        let tweaks = try Self.decodeFeed(data: data)

        // Persist raw validated envelope to cache
        let dir = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)

        return tweaks
    }
}
