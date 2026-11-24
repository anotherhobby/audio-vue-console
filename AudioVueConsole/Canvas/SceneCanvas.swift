import AppKit
import ConsoleCore
import SwiftUI
import UniformTypeIdentifiers

/// What the pointer is doing on the canvas, drawn live until it ends.
enum CanvasGesture: Equatable {
    case moving(CellOffset)
    case resizing(UUID, CardEdges, CellOffset)
    case marquee(CGRect)
    case dropping(kind: String, size: CellSize, cell: Cell)
}

/// The scene canvas: the panel's grid filling the display's outline, as the host stretches it,
/// and wider by the same cells for a scene too wide for the panel (`scene-canvas`, "The canvas
/// has the display's shape"). Cards parked off the panel are drawn and handled in the region's
/// own cells, off its grid, around the outline (`card-parking`). It turns pointer and key events
/// into `SceneEditor` calls and draws their results; every rule is the editor's.
struct SceneCanvas: View {
    let editor: SceneEditor
    /// The display's width over its height.
    let panelAspect: Double
    /// How many columns the panel's grid has; the scene's has more where it is too wide.
    let panelCols: Int
    /// A library card's size, by kind.
    let sizeOf: (String) -> CellSize?
    /// The scene's layers, or nil where the canvas draws boxes alone, as in previews.
    var rendering: SceneRendering?
    /// The scene's name above the panel, as the grid's size is below it.
    var title: SceneNameTitle?
    /// The scene as read, which writes the cards Copy and Cut take (`card-clipboard`).
    var laidOut: LaidOutScene?
    /// The cards the panel's schema marks placeable, by name, which Paste keeps to.
    var placeable: Set<String> = []

    @Environment(SceneStore.self) private var store
    @State private var gesture: CanvasGesture?
    @State private var pane = PaneFrame()
    /// The panel's size over its usual one, below 1 only to keep parked cards in view.
    @State private var scale: CGFloat = 1
    @FocusState private var isFocused: Bool

    /// The canvas pane's coordinate space, in which the region's frame is read.
    private static let paneSpace = "scene-canvas-pane"

    var body: some View {
        paneView
            // A click anywhere off a card, inside the panel or around it, clears the selection; a
            // card's own tap wins over this one.
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
                editor.clearSelection()
            }
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onDeleteCommand { editor.deleteSelection() }
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { nudge($0) }
            .focusedSceneValue(\.sceneEditor, editor)
            .modifier(
                CanvasClipboard(
                    editor: editor, laidOut: laidOut, reach: reach, panelCols: panelCols,
                    placeable: placeable)
            )
            // A resize draws its plate again at each cell step; everything else once it is committed,
            // and a refused gesture's plate as it was (`scene-rendering`).
            .onChange(of: drawnContent) { _, content in
                Task { await rendering?.show(content) }
            }
    }

    /// The canvas pane: the scene's name, the panel and the line below it, with the open pane
    /// behind them, measured so cards can be parked around the panel and the panel shrunk to keep
    /// them in view (`card-parking`).
    private var paneView: some View {
        ZStack {
            // Behind the column: a drag across the open pane draws a marquee there too.
            Color.clear.contentShape(Rectangle()).gesture(marquee(regionGeometry))
            PaneGrid(geometry: pane.geometry(grid))
            CanvasStack(scale: scale) {
                if let title { title.zIndex(1) }
                display.layoutValue(key: CanvasStack.Display.self, value: true)
                footer.zIndex(1)
            }
            .padding(CanvasMetrics.canvasPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(.named(Self.paneSpace))
        // The whole pane takes library drops: on the panel they land on it, off it they park
        // (`card-parking`, design D10).
        .onDrop(
            of: [.plainText],
            delegate: CanvasDropDelegate(
                editor: editor, geometry: pane.geometry(grid), reach: reach, store: store,
                sizeOf: sizeOf, gesture: $gesture)
        )
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: {
            pane.size = $0
        }
        .onChange(of: FitInputs(pane: pane, parked: editor.content.parked.map(\.cells))) {
            fit()
        }
    }

    /// What the layers are drawn for: the scene as the editor holds it, and its cards as a resize
    /// would leave them while one is under way.
    private var drawnContent: SceneContent {
        if case .resizing = gesture { return shownContent }
        return editor.content
    }

    /// Whether the scene is drawn by the helper rather than as boxes.
    private var showsLayers: Bool { rendering.map { !$0.showsBoxes } ?? false }

    private var grid: CellSize { editor.layout.grid }

    /// Whether a card ends past the panel's last column, so the panel would refuse the scene.
    private var isTooWide: Bool { editor.layout.cards.contains { $0.cells.maxCol > panelCols } }

    /// The canvas's width over its height: the display's, wider by the columns past the panel's.
    private var aspect: Double { panelAspect * Double(grid.cols) / Double(panelCols) }

    /// Where a parked card may go: the pane's whole cells, from the grid's top-left.
    private var reach: CellRect { pane.reach(grid) }

    /// The region's grid in its own points, which reach past it to the parked cards.
    private var regionGeometry: GridGeometry { GridGeometry(grid: grid, size: pane.region.size) }

    private var display: some View {
        ZStack {
            if let rendering, showsLayers {
                LayerStack(
                    rendering: rendering, grid: grid, panelCols: panelCols, shown: shownContent)
            } else {
                // A scene with no cards is drawn by no request of the canvas's; the library's
                // tiles hold its backdrop.
                SceneBackdrop(
                    image: editor.layout.cards.isEmpty ? store.tiles.backdrop?.image : nil)
            }
            GeometryReader { proxy in
                region(GridGeometry(grid: grid, size: proxy.size))
                    .onGeometryChange(for: CGRect.self) {
                        $0.frame(in: .named(Self.paneSpace))
                    } action: {
                        pane.region = $0
                    }
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .padding(CanvasMetrics.bezelWidth)
        .background(.black, in: RoundedRectangle(cornerRadius: CanvasMetrics.bezelCornerRadius))
    }

    /// The scene's region: the marquee surface, the plates, a hit target per card, on the grid
    /// or parked off it, the outlines and the handles, in that order from the back.
    private func region(_ geometry: GridGeometry) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear.contentShape(Rectangle()).gesture(marquee(geometry))
            if !showsLayers {
                LayoutPlates(layout: shownContent.layout).allowsHitTesting(false)
                ParkedBoxes(cards: shownContent.parked, geometry: geometry)
            }
            if grid.cols > panelCols {
                // Over the plates: the columns the panel lacks (`scene-canvas`, "A scene too wide shows the
                // columns the panel lacks").
                Rectangle().fill(.black.opacity(CanvasMetrics.lackingColumnsOpacity))
                    .placed(at: geometry.rect(of: lackingColumns))
                    .allowsHitTesting(false)
            }
            ForEach(editor.content.cards) { target($0, geometry) }
            CanvasOutlines(
                rects: outlineRects(geometry), isRefused: isRefused, marquee: marqueeRect)
            if let card = editor.resizableCard {
                CanvasHandles(
                    card: card, rect: geometry.rect(of: shownCells(of: card)),
                    geometry: geometry, reach: reach, editor: editor, gesture: $gesture)
            }
        }
    }

    /// The cells past the panel's last column.
    private var lackingColumns: CellRect {
        CellRect(col: panelCols, row: 0, cols: grid.cols - panelCols, rows: grid.rows)
    }

    private var footer: some View {
        VStack {
            footerLine
            ForEach(rendering?.messages ?? [], id: \.self) { message in
                Text(message).foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }

    private var tooWideMessage: String? {
        isTooWide
            ? "This scene is too wide for this panel. Move its cards into the first "
                + "\(panelCols) columns to apply it."
            : nil
    }

    /// The canvas's line: a refusal, why the scene cannot be edited, the parked cards, a scene
    /// too wide, or the grid's size, the first that holds (`card-parking`, "The canvas says how
    /// many cards are parked").
    private var footerLine: some View {
        Group {
            if let message = (previewRefusal ?? editor.refusal)?.description
                ?? editor.readOnly?.description ?? parkedMessage ?? tooWideMessage
            {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Text(verbatim: "Scene grid: \(grid.cols) × \(grid.rows)")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }

    private var parkedMessage: String? {
        editor.hasParked ? ParkingText.canvas(editor.content.parked.count) : nil
    }

    // MARK: Pointer

    /// A card's click and drag area, on the grid or parked: a click selects it, shift-click adds
    /// or removes it, and a drag moves the selection, selecting the card first if it was not.
    private func target(_ card: LayoutCard, _ geometry: GridGeometry) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .placed(at: geometry.rect(of: card.cells))
            .onTapGesture { pick(card) }
            .gesture(
                DragGesture(minimumDistance: CanvasMetrics.dragMinimumDistance)
                    .onChanged { value in
                        if gesture == nil, !editor.selection.contains(card.id) { pick(card) }
                        gesture = .moving(geometry.offset(for: value.translation))
                    }
                    .onEnded { value in
                        editor.drag(by: geometry.offset(for: value.translation), within: reach)
                        gesture = nil
                    })
    }

    /// A marquee over the region or the pane around it, read in the pane and kept in the
    /// region's points, selecting every card it touches, on the grid or parked.
    private func marquee(_ geometry: GridGeometry) -> some Gesture {
        DragGesture(
            minimumDistance: CanvasMetrics.marqueeMinimumDistance,
            coordinateSpace: .named(Self.paneSpace)
        )
        .onChanged { value in
            gesture = .marquee(regionRect(from: value.startLocation, to: value.location))
        }
        .onEnded { value in
            let rect = regionRect(from: value.startLocation, to: value.location)
            isFocused = true
            editor.select(touching: geometry.cellsOnAndOff(touching: rect), adding: isShiftDown)
            gesture = nil
        }
    }

    private func pick(_ card: LayoutCard) {
        isFocused = true
        if isShiftDown { editor.toggle(card.id) } else { editor.select(card.id) }
    }

    private var isShiftDown: Bool { NSEvent.modifierFlags.contains(.shift) }

    /// The rectangle from `start` to `end`, points in the pane, in the region's points.
    private func regionRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x) - pane.region.minX, y: min(start.y, end.y) - pane.region.minY,
            width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    // MARK: Keyboard

    private func nudge(_ press: KeyPress) -> KeyPress.Result {
        guard !editor.selection.isEmpty else { return .ignored }
        let isShifted = press.modifiers.contains(.shift)
        let step = isShifted ? CanvasMetrics.shiftedNudge : CanvasMetrics.nudge
        let offset =
            switch press.key {
            case .leftArrow: CellOffset(cols: -step, rows: 0)
            case .rightArrow: CellOffset(cols: step, rows: 0)
            case .upArrow: CellOffset(cols: 0, rows: -step)
            default: CellOffset(cols: 0, rows: step)
            }
        editor.nudge(by: offset, within: reach)
        return .handled
    }

    // MARK: Fitting the panel to the parked cards

    /// What decides the panel's scale: the pane, and where the cards are parked once committed.
    private struct FitInputs: Equatable {
        let pane: PaneFrame
        let parked: [CellRect]
    }

    /// Draws the panel as large as it can be, up to its usual size, with every parked card in
    /// the pane (`card-parking`, "Every parked card stays in view").
    private func fit() {
        let next = pane.fitted(grid, parked: editor.content.parked.map(\.cells), from: scale)
        if abs(next - scale) > CanvasMetrics.fitTolerance { scale = next }
    }

    // MARK: What a gesture shows

    private var preview: Result<SceneContent, LayoutRefusal>? {
        switch gesture {
        case .moving(let offset): editor.previewDrag(by: offset, within: reach)
        case .resizing(let id, let edges, let offset):
            editor.previewResize(id, edges: edges, by: offset, within: reach)
        case .dropping(let kind, let size, let cell):
            editor.previewDrop(kind: kind, size: size, at: cell, within: reach)
        case .marquee, nil: nil
        }
    }

    /// The scene as a successful gesture would leave it, or as it is.
    private var shownContent: SceneContent {
        if case .success(let content) = preview { return content }
        return editor.content
    }

    private var previewRefusal: LayoutRefusal? {
        if case .failure(let refusal) = preview { return refusal }
        return nil
    }

    private var isRefused: Bool { previewRefusal != nil }

    private var marqueeRect: CGRect? {
        if case .marquee(let rect) = gesture { return rect }
        return nil
    }

    private func shownCells(of card: LayoutCard) -> CellRect {
        shownContent.card(card.id)?.cells ?? card.cells
    }

    /// What to outline: the selection where it is or would go, and a dropped card's cells.
    private func outlineRects(_ geometry: GridGeometry) -> [CGRect] {
        let cells: [CellRect] =
            switch (gesture, preview) {
            case (.dropping(_, let size, let cell), let shown):
                [CanvasDropDelegate.outline(of: size, at: cell, in: editor, shown: shown)]
            case (.moving(let offset), .failure):
                editor.selectedCards.map { $0.cells.offset(by: offset) }
            default:
                editor.selectedCards.map(shownCells(of:))
            }
        return cells.map(geometry.rect(of:))
    }
}

#Preview("Canvas, an 8:3 panel") {
    if let layout = PlatesPreview.layout(on: CellSize(cols: 96, rows: 36)) {
        SceneCanvas(
            editor: SceneEditor(layout: layout), panelAspect: 8.0 / 3.0, panelCols: 96,
            sizeOf: { _ in nil }
        )
        .environment(SceneStore())
        .frame(width: 900, height: 420)
    }
}

#Preview("Canvas, too wide for a 61-column panel") {
    if let layout = PlatesPreview.layout(on: CellSize(cols: 61, rows: 36)) {
        SceneCanvas(
            editor: SceneEditor(layout: layout), panelAspect: 1024.0 / 600.0, panelCols: 61,
            sizeOf: { _ in nil }
        )
        .environment(SceneStore())
        .frame(width: 900, height: 420)
    }
}

#Preview("Canvas, a card parked below the panel") {
    if let layout = PlatesPreview.layout(on: CellSize(cols: 96, rows: 36)),
        let waveform = layout.cards.last
    {
        let editor = SceneEditor(layout: layout)
        let _ = editor.select(waveform.id)
        let _ = editor.drag(
            by: CellOffset(cols: 0, rows: 20),
            within: CellRect(col: -20, row: -20, cols: 136, rows: 80))
        SceneCanvas(editor: editor, panelAspect: 8.0 / 3.0, panelCols: 96, sizeOf: { _ in nil })
            .environment(SceneStore())
            .frame(width: 900, height: 600)
    }
}
