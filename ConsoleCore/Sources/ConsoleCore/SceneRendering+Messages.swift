/// What the canvas says about a scene's drawing, decided here so tests reach it (`scene-rendering`).
extension SceneRendering {
    /// Each thing to say, most important first: why the scene is boxes, if it is, then what the
    /// helper said about the backdrop, a stand-in display size, and the cards too small to read.
    public var messages: [String] {
        var lines: [String] = []
        if let reason = statusMessage { lines.append(reason) }
        if let drift, !drift.families.isEmpty, !drift.sharesNothing {
            lines.append(familiesMessage(drift))
        }
        if let notice = noticeMessage { lines.append(notice) }
        if !displayKnown {
            lines.append(
                "The panel's display size isn't known, so this is drawn at "
                    + "\(context.display.width) by \(context.display.height).")
        }
        if !unfit.isEmpty {
            let names = unfit.map { $0.replacingOccurrences(of: "_", with: " ") }
            lines.append("Too small to show its reading: \(names.joined(separator: ", ")).")
        }
        return lines
    }

    /// Whether the cards are plain boxes: nothing the helper drew is held for the scene.
    public var showsBoxes: Bool { backdrop == nil }

    private var statusMessage: String? {
        switch status {
        case .waiting: "The renderer is starting."
        case .drawing where backdrop == nil: "Drawing the scene…"
        case .drawing, .drawn: nil
        case .noRenderer(let reason): reason
        case .refused(let reason): "The panel would refuse this scene: \(reason)"
        case .failed: "The renderer stopped while drawing this scene. It starts again next time."
        case .codeDiffers(let entries):
            "This app's code for \(CardDrift.listed(entries)) differs from the panel's, "
                + "so no card is drawn. \(comparedWith)"
        }
    }

    private func familiesMessage(_ drift: CardDrift) -> String {
        let names = drift.families.sorted().map { $0.replacingOccurrences(of: "_", with: " ") }
        return "This app's code for \(CardDrift.listed(names)) differs from the panel's, "
            + "so those cards are plain boxes. \(comparedWith)"
    }

    /// Which of the panel's code the comparison is with.
    private var comparedWith: String {
        drift?.source == .host
            ? "The panel isn't running, so this is the code it will run at its next start."
            : "Deploy audio-vue to the panel, or rebuild the app with the panel's code."
    }

    private var noticeMessage: String? {
        switch notice {
        case "BACKDROP IMAGE MISSING"?: "The backdrop image is missing, so the default is shown."
        case "BACKDROP IMAGE UNREADABLE"?:
            "The backdrop image can't be read, so the default is shown."
        case let other?: other
        case nil: nil
        }
    }
}
