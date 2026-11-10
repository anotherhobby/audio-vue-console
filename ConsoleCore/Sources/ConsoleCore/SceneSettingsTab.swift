/// The inspector's tabs over a scene's blocks, so no tab is a long list (`scene-settings`, "The
/// inspector shows the scene's settings when no card is selected"; design D2).
public enum SceneSettingsTab: String, Sendable, CaseIterable, Identifiable {
    case look, colours, analysis, grid
    /// Every block no other tab holds, as one the app does not know.
    case other

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .look: "Look"
        case .colours: "Colours"
        case .analysis: "Analysis"
        case .grid: "Grid"
        case .other: "Other"
        }
    }

    /// The blocks this tab holds, by name, in order; none for Other, which holds the rest.
    var blockNames: [String] {
        switch self {
        case .look: ["backdrop", "glass", "type"]
        case .colours: ["palette", "elements"]
        case .analysis: ["analysis", "display"]
        case .grid: ["grid"]
        case .other: []
        }
    }
}

extension SchemaFacts {
    /// The blocks `tab` shows, in its order: for Other, every block no other tab names, by name.
    public func blocks(on tab: SceneSettingsTab) -> [Block] {
        guard tab == .other else { return tab.blockNames.compactMap(block) }
        let named = Set(SceneSettingsTab.allCases.flatMap(\.blockNames))
        return blocks.filter { !named.contains($0.name) }
    }

    /// The tabs with a block to show, in order.
    public var settingsTabs: [SceneSettingsTab] {
        SceneSettingsTab.allCases.filter { !blocks(on: $0).isEmpty }
    }
}
