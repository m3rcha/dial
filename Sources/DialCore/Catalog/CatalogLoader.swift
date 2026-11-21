import Foundation

public enum CatalogLoaderError: Error, LocalizedError, Sendable {
    case bundledCatalogMissing

    public var errorDescription: String? {
        switch self {
        case .bundledCatalogMissing:
            return "Bundled tweaks.json could not be found in DialCore resources."
        }
    }
}

public enum CatalogLoader {
    public static func loadBundledCatalog() throws -> [Tweak] {
        guard let url = Bundle.module.url(forResource: "tweaks", withExtension: "json") else {
            throw CatalogLoaderError.bundledCatalogMissing
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Tweak].self, from: data)
    }

    public static func curatedProfiles() -> [Profile] {
        [
            Profile(
                id: "profile.minimal-dev",
                name: "Minimal Dev",
                description: "Fast Dock, dotfiles & extensions visible, key repeat enabled, expanded save panels.",
                symbolName: "terminal",
                isBuiltIn: true,
                selections: [
                    SetupTweakSelection(id: "dock.autohide", enabled: true),
                    SetupTweakSelection(id: "dock.autohide-delay", enabled: true, params: ["delay": .double(0.0)]),
                    SetupTweakSelection(id: "dock.hide-recents", enabled: true),
                    SetupTweakSelection(id: "finder.show-hidden-files", enabled: true),
                    SetupTweakSelection(id: "finder.show-extensions", enabled: true),
                    SetupTweakSelection(id: "finder.show-path-bar", enabled: true),
                    SetupTweakSelection(id: "keyboard.disable-press-and-hold", enabled: true),
                    SetupTweakSelection(id: "dev.expand-save-panel", enabled: true)
                ]
            ),
            Profile(
                id: "profile.presentation",
                name: "Presentation & Recording",
                description: "Hide desktop icons, hide Dock, clean window screenshots without shadows or thumbnails.",
                symbolName: "play.rectangle",
                isBuiltIn: true,
                selections: [
                    SetupTweakSelection(id: "desktop.hide-all-icons", enabled: true),
                    SetupTweakSelection(id: "dock.autohide", enabled: true),
                    SetupTweakSelection(id: "screenshots.disable-shadow", enabled: true),
                    SetupTweakSelection(id: "screenshots.hide-thumbnail", enabled: true)
                ]
            ),
            Profile(
                id: "profile.zero-animation",
                name: "Zero-Animation Speed",
                description: "Snappier window resize, no Dock bounce, instant Quick Look and Dock slide.",
                symbolName: "bolt",
                isBuiltIn: true,
                selections: [
                    SetupTweakSelection(id: "animations.instant-window-resize", enabled: true),
                    SetupTweakSelection(id: "animations.disable-window-open", enabled: true),
                    SetupTweakSelection(id: "animations.disable-dock-bounce", enabled: true),
                    SetupTweakSelection(id: "animations.disable-quicklook-anim", enabled: true)
                ]
            )
        ]
    }
}
