import AppKit
import DialCore
import Foundation
import Observation

public enum SidebarSection: Hashable, Identifiable {
    case modified
    case profiles
    case snapshots
    case community
    case category(TweakCategory)

    public var id: String {
        switch self {
        case .modified: return "modified"
        case .profiles: return "profiles"
        case .snapshots: return "snapshots"
        case .community: return "community"
        case .category(let cat): return "cat.\(cat.rawValue)"
        }
    }

    public var title: String {
        switch self {
        case .modified: return "Modified"
        case .profiles: return "Profiles"
        case .snapshots: return "Snapshots"
        case .community: return "Community"
        case .category(let cat): return cat.rawValue
        }
    }
}

@Observable
@MainActor
final class AppState {
    // MARK: - Dependencies
    private let engine: TweakEngine
    private let restarter: ServiceRestarting
    private let feedClient: CommunityFeedClient
    private let userProfilesURL: URL

    // MARK: - Catalog & Live State
    var builtInTweaks: [Tweak] = []
    var communityTweaks: [Tweak] = []
    var profiles: [Profile] = []
    var snapshots: [SnapshotEntry] = []

    var activeTweakIDs: Set<String> = []
    var modifiedTweakIDs: Set<String> = []
    var parameterValues: [String: [String: TweakValue]] = [:]

    // MARK: - Navigation & UI State
    var selection: SidebarSection? = .category(.dock)
    var searchText: String = ""
    var pendingServices: Set<AllowlistedService> = []
    var isRestartingServices: Bool = false

    var activeImportPreview: ImportPreview?
    var importErrorMessage: String?
    var toastMessage: String?

    var isLoadingCommunity: Bool = false
    var communityErrorMessage: String?

    // MARK: - Settings
    var autoRestartServices: Bool {
        didSet {
            UserDefaults.standard.set(autoRestartServices, forKey: "dial.autoRestartServices")
        }
    }
    var showMenuBarExtra: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarExtra, forKey: "dial.showMenuBarExtra")
            onMenuBarSettingChanged?(showMenuBarExtra)
        }
    }
    var communityFeedURL: String {
        didSet {
            UserDefaults.standard.set(communityFeedURL, forKey: "dial.communityFeedURL")
        }
    }
    var onMenuBarSettingChanged: ((Bool) -> Void)?

    var allTweaks: [Tweak] {
        builtInTweaks + communityTweaks
    }

    var supportedTweaks: [Tweak] {
        allTweaks.filter { $0.isSupported(on: engine.currentOS) }
    }

    var currentOSDescription: String {
        "macOS \(engine.currentOS.formatted)"
    }

    init(
        engine: TweakEngine = TweakEngine(),
        restarter: ServiceRestarting = ServiceRestarter(),
        feedClient: CommunityFeedClient = CommunityFeedClient()
    ) {
        self.engine = engine
        self.restarter = restarter
        self.feedClient = feedClient

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.userProfilesURL = appSupport
            .appendingPathComponent("Dial", isDirectory: true)
            .appendingPathComponent("profiles.json")

        if UserDefaults.standard.object(forKey: "dial.autoRestartServices") == nil {
            self.autoRestartServices = true
        } else {
            self.autoRestartServices = UserDefaults.standard.bool(forKey: "dial.autoRestartServices")
        }
        self.showMenuBarExtra = UserDefaults.standard.bool(forKey: "dial.showMenuBarExtra")
        self.communityFeedURL = UserDefaults.standard.string(forKey: "dial.communityFeedURL")
            ?? CommunityFeedClient.defaultFeedURLString

        loadInitialData()
    }

    func loadInitialData() {
        builtInTweaks = (try? CatalogLoader.loadBundledCatalog()) ?? []
        loadProfiles()
        Task {
            communityTweaks = await feedClient.loadCachedTweaks()
            snapshots = await engine.snapshots.allSnapshots()
            refreshLiveState()
        }
    }

    func refreshLiveState() {
        var active: Set<String> = []
        var modified: Set<String> = []
        var params: [String: [String: TweakValue]] = [:]

        for tweak in allTweaks {
            if engine.isActive(tweak) {
                active.insert(tweak.id)
            }
            if engine.isModifiedFromStock(tweak) {
                modified.insert(tweak.id)
            }
            let p = engine.currentParameterValues(for: tweak)
            if !p.isEmpty {
                params[tweak.id] = p
            }
        }

        activeTweakIDs = active
        modifiedTweakIDs = modified
        parameterValues = params
    }

    func filteredTweaks(for section: SidebarSection) -> [Tweak] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let base: [Tweak]
        if !query.isEmpty {
            base = supportedTweaks
        } else {
            switch section {
            case .category(let cat):
                base = supportedTweaks.filter { $0.category == cat }
            case .modified:
                base = supportedTweaks.filter { modifiedTweakIDs.contains($0.id) }
            case .community:
                base = communityTweaks.filter { $0.isSupported(on: engine.currentOS) }
            case .profiles, .snapshots:
                base = []
            }
        }

        guard !query.isEmpty else { return base }
        return base.filter { tweak in
            tweak.name.lowercased().contains(query)
                || tweak.description.lowercased().contains(query)
                || tweak.id.lowercased().contains(query)
                || tweak.keywords.contains(where: { $0.lowercased().contains(query) })
                || tweak.operations.contains(where: {
                    $0.key.lowercased().contains(query) || $0.domain.lowercased().contains(query)
                })
        }
    }

    func modifiedCount(for category: TweakCategory) -> Int {
        supportedTweaks.filter { $0.category == category && modifiedTweakIDs.contains($0.id) }.count
    }

    func unmetPrerequisites(for tweak: Tweak) -> [TweakPrerequisite] {
        engine.unmetPrerequisites(for: tweak, catalog: allTweaks)
    }

    // MARK: - Actions

    func setTweak(_ tweak: Tweak, enabled: Bool) async {
        let params = parameterValues[tweak.id]
        let selection = SetupTweakSelection(id: tweak.id, enabled: enabled, params: params)
        do {
            let services = try await engine.apply(
                selections: [selection],
                catalog: allTweaks,
                snapshotTitle: "\(enabled ? "Enable" : "Disable") \(tweak.name)"
            )
            handleAffectedServices(services)
            snapshots = await engine.snapshots.allSnapshots()
            refreshLiveState()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    func updateParameter(for tweak: Tweak, parameterID: String, value: TweakValue) async {
        var current = parameterValues[tweak.id] ?? [:]
        current[parameterID] = value
        parameterValues[tweak.id] = current

        let selection = SetupTweakSelection(id: tweak.id, enabled: true, params: current)
        do {
            let services = try await engine.apply(
                selections: [selection],
                catalog: allTweaks,
                snapshotTitle: "Update \(tweak.name)"
            )
            handleAffectedServices(services)
            snapshots = await engine.snapshots.allSnapshots()
            refreshLiveState()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    func resetToStock(_ tweak: Tweak) async {
        do {
            let services = try await engine.resetToStock(tweak: tweak)
            handleAffectedServices(services)
            snapshots = await engine.snapshots.allSnapshots()
            refreshLiveState()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    func exportMyMacToPasteboard() {
        let payload = engine.exportModifiedSetup(name: Host.current().localizedName ?? "My Mac", catalog: allTweaks)
        guard !payload.tweaks.isEmpty else {
            showToast("No modified tweaks detected to export.")
            return
        }
        do {
            let code = try SetupCodeCodec.encode(payload)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
            showToast("Copied setup code (\(payload.tweaks.count) tweaks) to clipboard.")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    func handleIncomingSetupString(_ raw: String) {
        Task {
            do {
                let payload = try SetupCodeCodec.decode(raw)
                let localIDs = Set(allTweaks.map(\.id))
                let hasUnknown = payload.tweaks.contains { !localIDs.contains($0.id) }
                if hasUnknown {
                    await refreshCommunityFeedSilently()
                }
                activeImportPreview = engine.previewImport(payload, catalog: allTweaks)
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    func handlePasteFromClipboard() {
        guard let str = NSPasteboard.general.string(forType: .string) else {
            importErrorMessage = "Clipboard does not contain text."
            return
        }
        handleIncomingSetupString(str)
    }

    func applyImport(items: [ImportPreviewItem], selectedIDs: Set<String>, setupName: String) async {
        let selections = items
            .filter { selectedIDs.contains($0.id) }
            .map(\.selection)
        guard !selections.isEmpty else { return }

        do {
            let services = try await engine.apply(
                selections: selections,
                catalog: allTweaks,
                snapshotTitle: "Import: \(setupName)"
            )
            handleAffectedServices(services)
            snapshots = await engine.snapshots.allSnapshots()
            refreshLiveState()
            activeImportPreview = nil
            showToast("Applied \(selections.count) tweaks from \"\(setupName)\".")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    func activateProfile(_ profile: Profile) async {
        do {
            let services = try await engine.apply(
                selections: profile.selections,
                catalog: allTweaks,
                snapshotTitle: "Profile: \(profile.name)"
            )
            handleAffectedServices(services)
            snapshots = await engine.snapshots.allSnapshots()
            refreshLiveState()
            showToast("Activated \"\(profile.name)\" profile.")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    func saveCurrentAsProfile(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let exported = engine.exportModifiedSetup(name: trimmed, catalog: allTweaks)
        let profile = Profile(
            id: "profile.user.\(UUID().uuidString)",
            name: trimmed,
            description: "\(exported.tweaks.count) active tweaks captured from this Mac.",
            symbolName: "slider.horizontal.3",
            isBuiltIn: false,
            selections: exported.tweaks
        )
        profiles.append(profile)
        persistUserProfiles()
        showToast("Saved profile \"\(trimmed)\".")
    }

    func deleteUserProfile(_ profile: Profile) {
        guard !profile.isBuiltIn else { return }
        profiles.removeAll { $0.id == profile.id }
        persistUserProfiles()
    }

    func revertSnapshot(_ entry: SnapshotEntry) async {
        do {
            let services = try await engine.revertSnapshot(id: entry.id)
            handleAffectedServices(services)
            snapshots = await engine.snapshots.allSnapshots()
            refreshLiveState()
            showToast("Reverted \"\(entry.title)\".")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func handleAffectedServices(_ services: Set<AllowlistedService>) {
        guard !services.isEmpty else { return }
        pendingServices.formUnion(services)
        if autoRestartServices {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                await restartPendingServices()
            }
        }
    }

    func restartPendingServices() async {
        guard !pendingServices.isEmpty else { return }
        isRestartingServices = true
        let toRestart = pendingServices
        _ = await restarter.restart(services: toRestart)
        pendingServices.removeAll()
        isRestartingServices = false
        refreshLiveState()
    }

    func refreshCommunityFeed() async {
        isLoadingCommunity = true
        communityErrorMessage = nil
        do {
            communityTweaks = try await feedClient.fetch(from: communityFeedURL)
            refreshLiveState()
        } catch {
            communityErrorMessage = error.localizedDescription
        }
        isLoadingCommunity = false
    }

    private func refreshCommunityFeedSilently() async {
        if let fetched = try? await feedClient.fetch(from: communityFeedURL) {
            communityTweaks = fetched
        }
    }

    private func loadProfiles() {
        let builtIn = CatalogLoader.curatedProfiles()
        var custom: [Profile] = []
        if let data = try? Data(contentsOf: userProfilesURL),
           let decoded = try? JSONDecoder().decode([Profile].self, from: data) {
            custom = decoded
        }
        profiles = builtIn + custom
    }

    private func persistUserProfiles() {
        let custom = profiles.filter { !$0.isBuiltIn }
        let dir = userProfilesURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(custom) {
            try? data.write(to: userProfilesURL, options: .atomic)
        }
    }

    func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}
