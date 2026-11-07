import CoreGraphics
import Foundation
import Observation

/// One open scene's layers, kept matching the layout the canvas shows (`scene-rendering`). Each
/// plate's layer is kept with the cells it was drawn for, so the canvas can slide or stretch it to
/// where the plate is now until the plate is drawn again there.
@MainActor @Observable
public final class SceneRendering {
    public enum Status: Sendable, Equatable {
        /// The renderer has not made its first run yet.
        case waiting
        case drawing
        case drawn
        /// No renderer can draw: this build has none, or it could not start, and why.
        case noRenderer(String)
        /// The helper refused the scene, with the panel's reason.
        case refused(String)
        /// The helper ended while drawing.
        case failed
        /// Code every card draws through differs from the panel's: these shared entries.
        case codeDiffers([String])
    }

    /// A plate's layer and the cells its plate covered when it was drawn.
    public struct PlacedLayer: Sendable {
        public let layer: RenderedLayer
        public let cells: CellRect
    }

    public private(set) var backdrop: RenderedLayer?
    public private(set) var plates: [Set<UUID>: PlacedLayer] = [:]
    public private(set) var status = Status.waiting
    /// What the helper said about the backdrop's image, such as `BACKDROP IMAGE MISSING`.
    public private(set) var notice: String?
    /// How the app's card code differs from the panel's, where it does.
    public private(set) var drift: CardDrift?
    /// Whether the host gave the panel's display size, so the scene is not drawn at a stand-in.
    public let displayKnown: Bool
    public let context: RenderContext

    /// The scene as read, its document and the layout it opened with.
    public let scene: LaidOutScene
    private var queue: RenderQueue?
    private var layout: SceneLayout
    private var inFlight = 0

    public init(scene: LaidOutScene, context: RenderContext, displayKnown: Bool) {
        self.scene = scene
        self.context = context
        self.displayKnown = displayKnown
        layout = scene.layout
    }

    /// Starts drawing with `queue`, once the renderer has made its first run.
    public func attach(_ queue: RenderQueue) async {
        if case .codeDiffers = status { return }
        self.queue = queue
        await show(layout)
    }

    /// No renderer will draw this scene, for `reason`.
    public func unavailable(_ reason: String) {
        queue = nil
        clear(.noRenderer(reason))
    }

    /// Takes what comparing the card code found: a shared difference, or a damaged bundle, draws
    /// nothing by the helper; a card family's difference boxes that family's cards (`card-code`).
    public func apply(_ verdict: CardCodeVerdict) {
        switch verdict {
        case .same:
            drift = nil
        case .damagedBundle:
            unavailable("This app's render bundle doesn't match its manifest. Rebuild the app.")
        case .unreadable:
            unavailable("The panel's card code can't be read. Deploy audio-vue to the panel.")
        case .differs(let drift):
            self.drift = drift
            if drift.sharesNothing {
                queue = nil
                clear(.codeDiffers(drift.shared))
            }
        }
    }

    /// The cards drawn as plain boxes over their plates, their family's code differing.
    public var boxedCards: Set<UUID> {
        guard let drift else { return [] }
        return Set(layout.cards.filter { drift.boxes($0.kind) }.map(\.id))
    }

    /// Draws again whatever `layout` changed, dropping the layers of plates it no longer has.
    public func show(_ layout: SceneLayout) async {
        self.layout = layout
        guard let queue else { return }
        guard backdrop != nil else {
            await draw(layout, plates: nil, through: queue)
            return
        }
        let changes = PlateChanges.needed(drawn: plates.mapValues(\.cells), for: layout)
        for removed in changes.removed { plates[removed] = nil }
        await withDiscardingTaskGroup { group in
            for plate in changes.redraw {
                group.addTask { await self.draw(layout, plates: plate, through: queue) }
            }
        }
    }

    /// The names of the cards that cannot show their reading at the size drawn.
    public var unfit: [String] {
        plates.values.flatMap(\.layer.unfit).sorted()
    }

    /// The plates' layers in the order the helper stacks them: cards in no group in placement
    /// order, then the groups.
    public var orderedPlates: [PlacedLayer] {
        let order = Dictionary(
            uniqueKeysWithValues: layout.cards.enumerated().map { ($1.id, $0) })
        return plates.values.sorted { first, second in
            let firstGrouped = first.layer.cardIDs.count > 1
            let secondGrouped = second.layer.cardIDs.count > 1
            if firstGrouped != secondGrouped { return secondGrouped }
            return Self.position(of: first, in: order) < Self.position(of: second, in: order)
        }
    }

    /// Draws `plate`, or every plate and the backdrop when nil, as `layout` places them.
    private func draw(_ layout: SceneLayout, plates plate: Set<UUID>?, through queue: RenderQueue)
        async
    {
        let ids = layout.cards.map(\.id)
        let chosen = plate.flatMap { members in ids.firstIndex(where: members.contains) }
        let request = RenderRequest(
            doc: scene.doc(for: layout), builtIn: scene.document.builtIn, context: context,
            plates: chosen.map { [$0] }, backdrop: plate == nil)
        let key = plate.map { "plate:" + $0.map(\.uuidString).sorted().joined(separator: ",") }
        begin()
        let result = await queue.submit(request.message, lane: .canvas, key: key ?? "scene")
        defer { end() }
        // A verdict or a failure that stopped drawing while this was under way wins over its answer.
        guard self.queue != nil else { return }
        switch result {
        case nil: return
        case .success(let answer)?: take(answer, drawnFor: layout, cardIDs: ids)
        case .failure(.refused(let reason))?: clear(.refused(reason))
        case .failure(.unavailable(let reason))?: clear(.noRenderer(reason))
        case .failure?: clear(.failed)
        }
    }

    private func take(_ answer: HelperAnswer, drawnFor drawn: SceneLayout, cardIDs: [UUID]) {
        let layers: [RenderedLayer]
        do {
            layers = try RenderedLayer.layers(of: answer, cardIDs: cardIDs)
        } catch {
            clear(.failed)
            return
        }
        notice = answer.header["notice"]?.stringValue
        let current = PlateChanges.cells(of: layout)
        let drawnCells = PlateChanges.cells(of: drawn)
        for layer in layers {
            let members = Set(layer.cardIDs)
            if layer.kind == .backdrop {
                backdrop = layer
            } else if current[members] != nil, let cells = drawnCells[members] {
                plates[members] = PlacedLayer(layer: layer, cells: cells)
            }
        }
    }

    private func clear(_ status: Status) {
        backdrop = nil
        plates = [:]
        notice = nil
        self.status = status
    }

    private func begin() {
        inFlight += 1
        switch status {
        case .noRenderer, .codeDiffers: return
        default: status = .drawing
        }
    }

    private func end() {
        inFlight -= 1
        if inFlight == 0, status == .drawing { status = .drawn }
    }

    private static func position(of placed: PlacedLayer, in order: [UUID: Int]) -> Int {
        placed.layer.cardIDs.compactMap { order[$0] }.min() ?? Int.max
    }
}
