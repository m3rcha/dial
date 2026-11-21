import Foundation

public actor SnapshotStore {
    private let fileURL: URL
    private var entries: [SnapshotEntry] = []
    private var loaded = false

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = appSupport
                .appendingPathComponent("Dial", isDirectory: true)
                .appendingPathComponent("snapshots.json")
        }
    }

    public func allSnapshots() -> [SnapshotEntry] {
        loadIfNeeded()
        return entries
    }

    public func record(_ entry: SnapshotEntry) throws {
        loadIfNeeded()
        entries.insert(entry, at: 0)
        // Keep last 100 snapshots
        if entries.count > 100 {
            entries = Array(entries.prefix(100))
        }
        try persist()
    }

    public func remove(id: UUID) throws {
        loadIfNeeded()
        entries.removeAll { $0.id == id }
        try persist()
    }

    public func clearAll() throws {
        loadIfNeeded()
        entries.removeAll()
        try persist()
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([SnapshotEntry].self, from: data) {
            entries = decoded
        }
    }

    private func persist() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: .atomic)
    }
}
