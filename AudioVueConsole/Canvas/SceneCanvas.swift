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

/// The scene canvas: the scene's grid fitted inside the panel's outline, as the host fits it, with
/// the backdrop around it. It turns pointer and key events into `SceneEditor` calls and draws
/// their results; every rule is the editor's (`scene-canvas`).
struct SceneCanvas: View {
    let editor: SceneEditor
    /// The panel's width over its height.
    let panelAspect: Double
    /// A library card's size, by kind.
    let sizeOf: (String) -> CellSize?
    /// The scene's layers, or nil where the canvas draws boxes alone, as in previews.
    var rendering: SceneRendering?
    /// The scene's name above the panel, as the grid's size is below it.
    var title: SceneNameTitle?

    @Environment(SceneStore.self) private var store
    @State private var gesture: CanvasGesture?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack {
            if let title { title }
            display
            footer
        }
        .padding(CanvasMetrics.canvasPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        // A resize draws its plate again at each cell step; everything else once it is committed,
        // and a refused gesture's plate as it was (`scene-rendering`).
        .onChange(of: drawnLayout) { _, layout in
            Task { await rendering?.show(layout) }
        }
    }

    /// The layout the layers are drawn for: as a resize would leave it while one is under way, and
    /// as the editor holds it otherwise.
    private var drawnLayout: SceneLayout {
        if case .resizing = gesture { return shownLayout }
        return editor.layout
    }

    /// Whether the scene is drawn by the helper rather than as boxes.
    private var showsLayers: Bool { rendering.map { !$0.showsBoxes } ?? false }

    private var grid: CellSize { editor.layout.grid }

    private var display: some View {
        ZStack {
            if let rendering, showsLayers {
                LayerStack(rendering: rendering, grid: grid, shown: shownLayout)
            } else {
                CanvasMetrics.backdrop
            }
            GeometryReader { proxy in
                region(GridGeometry(grid: grid, size: proxy.size))
            }
            .aspectRatio(CGFloat(grid.cols) / CGFloat(grid.rows), contentMode: .fit)
        }
        .aspectRatio(panelAspect, contentMode: .fit)
        .padding(CanvasMetrics.bezelWidth)
        .background(.black, in: RoundedRectangle(cornerRadius: CanvasMetrics.bezelCornerRadius))
    }

    /// The scene's region: the marquee surface, the plates, a hit target per card, the outlines
    /// and the handles, in that order from the back.
    private func region(_ geometry: GridGeometry) -> some View {
        ZStack(alignment: .topLeading) {
            marqueeSurface(geometry)
            if !showsLayers { LayoutPlates(layout: shownLayout).allowsHitTesting(false) }
            ForEach(editor.layout.cards) { target($0, geometry) }
            CanvasOutlines(rects: outlineRects(geometry), isRefused: isRefused, marquee: marquee)
            if let card = editor.resizableCard {
                CanvasHandles(
                    card: card, rect: geometry.rect(of: shownCells(of: card)),
                    geometry: geometry, editor: editor, gesture: $gesture)
            }
        }
        .onDrop(
            of: [.plainText],
            delegate: CanvasDropDelegate(
                editor: editor, geometry: geometry, store: store, sizeOf: sizeOf,
                gesture: $gesture))
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

    private var footerLine: some View {
        Group {
            if let message = (previewRefusal ?? editor.refusal)?.description
                ?? editor.readOnly?.description
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

    // MARK: Pointer

    /// A card's click and drag area: a click selects it, shift-click adds or removes it, and a
    /// drag moves the selection, selecting the card first if it was not.
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
                        editor.move(by: geometry.offset(for: value.translation))
                        gesture = nil
                    })
    }

    /// The empty region under the cards, where a drag draws a marquee.
    private func marqueeSurface(_ geometry: GridGeometry) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: CanvasMetrics.marqueeMinimumDistance)
                    .onChanged { value in
                        gesture = .marquee(Self.rect(from: value.startLocation, to: value.location))
                    }
                    .onEnded { value in
                        let rect = Self.rect(from: value.startLocation, to: value.location)
                        isFocused = true
                        editor.select(touching: geometry.cells(touching: rect), adding: isShiftDown)
                        gesture = nil
                    })
    }

    private func pick(_ card: LayoutCard) {
        isFocused = true
        if isShiftDown { editor.toggle(card.id) } else { editor.select(card.id) }
    }

    private var isShiftDown: Bool { NSEvent.modifierFlags.contains(.shift) }

    private static func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x),
            height: abs(end.y - start.y))
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
        editor.move(by: offset)
        return .handled
    }

    // MARK: What a gesture shows

    private var preview: Result<SceneLayout, LayoutRefusal>? {
        switch gesture {
        case .moving(let offset): editor.previewMove(by: offset)
        case .resizing(let id, let edges, let offset):
            editor.previewResize(id, edges: edges, by: offset)
        case .dropping(let kind, let size, let cell):
            editor.previewDrop(kind: kind, size: size, at: cell)
        case .marquee, nil: nil
        }
    }

    /// The layout as a successful gesture would leave it, or as it is.
    private var shownLayout: SceneLayout {
        if case .success(let layout) = preview { return layout }
        return editor.layout
    }

    private var previewRefusal: LayoutRefusal? {
        if case .failure(let refusal) = preview { return refusal }
        return nil
    }

    private var isRefused: Bool { previewRefusal != nil }

    private var marquee: CGRect? {
        if case .marquee(let rect) = gesture { return rect }
        return nil
    }

    private func shownCells(of card: LayoutCard) -> CellRect {
        shownLayout.card(card.id)?.cells ?? card.cells
    }

    /// What to outline: the selection where it is or would go, and a dropped card's cells.
    private func outlineRects(_ geometry: GridGeometry) -> [CGRect] {
        let layout = editor.layout
        let cells: [CellRect] =
            switch (gesture, preview) {
            case (.dropping(_, let size, let cell), _):
                [layout.placement(of: size, centredOn: cell)].compactMap(\.self)
            case (.moving(let offset), .failure):
                editor.selectedCards.map {
                    $0.cells.offset(by: layout.clampedOffset(editor.selection, by: offset))
                }
            default:
                editor.selectedCards.map(shownCells(of:))
            }
        return cells.map(geometry.rect(of:))
    }
}

/// The selection's outlines, red when a gesture is refused, and the marquee's rectangle.
struct CanvasOutlines: View {
    let rects: [CGRect]
    let isRefused: Bool
    let marquee: CGRect?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(rects.enumerated()), id: \.offset) { _, rect in
                RoundedRectangle(cornerRadius: CanvasMetrics.plateCornerRadius)
                    .strokeBorder(
                        isRefused ? Color.red : .accentColor,
                        lineWidth: CanvasMetrics.selectionLineWidth
                    )
                    .placed(at: rect)
            }
            if let marquee {
                Rectangle()
                    .fill(Color.accentColor.opacity(CanvasMetrics.marqueeFillOpacity))
                    .overlay { Rectangle().strokeBorder(Color.accentColor) }
                    .placed(at: marquee)
            }
        }
        .allowsHitTesting(false)
    }
}
