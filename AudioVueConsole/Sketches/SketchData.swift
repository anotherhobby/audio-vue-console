import ConsoleCore
import Foundation

/// Made-up panels for the sample pages, loaded from `sketch.json`. Throwaway: each page's own
/// change replaces it.
struct SketchData: Decodable {
    let panels: [SketchPanel]

    static let shared: SketchData = load()

    private static func load() -> SketchData {
        guard let url = Bundle.main.url(forResource: "sketch", withExtension: "json") else {
            return SketchData(panels: [])
        }
        do {
            return try JSONDecoder().decode(SketchData.self, from: Data(contentsOf: url))
        } catch {
            return SketchData(panels: [])
        }
    }
}

struct SketchPanel: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let condition: String
    let widthPx: Int
    let heightPx: Int
    let scene: String
    let calibratedDaysAgo: Int

    var isUp: Bool { condition == "up" }
    var shapeName: String { DisplayShape(width: widthPx, height: heightPx).description }
}
