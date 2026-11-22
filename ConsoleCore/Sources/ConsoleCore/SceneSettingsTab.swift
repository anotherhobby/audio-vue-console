/// The inspector's tabs over a scene's blocks, so no tab is a long list (`scene-settings`, "The
/// inspector shows the scene's settings when no card is selected"; design D2).
public enum SceneSettingsTab: String, Sendable, CaseIterable, Identifiable {
    case scene, style, analysis
    /// Every block no other tab holds, as one the app does not know.
    case other

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .scene: "Scene"
        case .style: "Style"
        case .analysis: "Analysis"
        case .other: "Other"
        }
    }

    /// The blocks this tab holds, by name, in order; none for Other, which holds the rest.
    var blockNames: [String] {
        switch self {
        case .scene: ["backdrop", "glass", "grid", "display"]
        case .style: ["colors", "type", "case"]
        case .analysis: ["analysis"]
        case .other: []
        }
    }

    /// The block each of the scene's own settings the app knows is listed with, by key: the
    /// typeface heads the text sizes. Any other is on Other, by its name.
    static let settingBlocks = ["typeface": "type"]
}

extension SchemaFacts {
    /// The blocks `tab` shows, in its order: for Other, every block no other tab names, by name.
    public func blocks(on tab: SceneSettingsTab) -> [Block] {
        guard tab == .other else { return tab.blockNames.compactMap(block) }
        let named = Set(SceneSettingsTab.allCases.flatMap(\.blockNames))
        return blocks.filter { !named.contains($0.name) }
    }

    /// The scene's own settings listed at the head of `block`'s section, in declared order.
    public func sceneSettings(with block: String) -> [SettingDeclaration] {
        sceneSettings.settings.filter { SceneSettingsTab.settingBlocks[$0.key] == block }
    }

    /// The scene's own settings `tab` shows apart from any block, in declared order: on Other,
    /// every one listed with no block the scene declares.
    public func sceneSettings(on tab: SceneSettingsTab) -> [SettingDeclaration] {
        guard tab == .other else { return [] }
        return sceneSettings.settings.filter { setting in
            SceneSettingsTab.settingBlocks[setting.key].flatMap(block) == nil
        }
    }

    /// The tabs with a block or a setting to show, in order.
    public var settingsTabs: [SceneSettingsTab] {
        SceneSettingsTab.allCases.filter {
            !blocks(on: $0).isEmpty || !sceneSettings(on: $0).isEmpty
        }
    }
}
