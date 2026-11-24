import AppKit
import ConsoleCore
import SwiftUI
import UniformTypeIdentifiers

/// Render with Track…: the open scene reading a track the user picks, shown at the moment chosen,
/// and saved as a still or a clip (`track-render`; design D5, D10).
struct TrackRenderSheet: View {
    let sceneName: String
    let render: TrackRender
    @Environment(\.dismiss) private var dismiss
    @State private var seconds = 0.0
    @State private var start = 0.0
    @State private var end = TrackRender.clipSeconds
    @State private var fps = ClipPlan.defaultFrameRate

    var body: some View {
        VStack(alignment: .leading, spacing: SceneMetrics.stripSpacing) {
            Text("Render “\(sceneName)” with a Track").font(.headline)
            trackRow
            if let failure = render.failure {
                Text(failure).font(.callout).foregroundStyle(.red)
            }
            picture
            notices
            if render.source != nil {
                scrubber
                clipRow
            }
            buttons
        }
        .padding()
        .frame(width: SceneMetrics.trackSheetWidth)
        .onDisappear { Task { await render.close() } }
    }

    private var trackRow: some View {
        HStack {
            Button("Choose Track…", action: chooseTrack)
                .disabled(render.isWorking || render.written != nil)
            if let source = render.source {
                Text(Self.describe(source, seconds: render.seconds))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var picture: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image = render.picture?.image {
                Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
            } else if !render.isWorking {
                Text("Choose a track to see the scene read it.").foregroundStyle(.secondary)
            }
            if render.isWorking { ProgressView() }
        }
        .aspectRatio(
            CGFloat(render.display.width) / CGFloat(max(render.display.height, 1)),
            contentMode: .fit
        )
        .frame(minHeight: SceneMetrics.trackPictureMinHeight)
    }

    @ViewBuilder private var notices: some View {
        let said = [render.opening?.notice, render.opening?.styleNotice].compactMap(\.self)
        ForEach(said, id: \.self) { Text($0).font(.callout).foregroundStyle(.secondary) }
    }

    private var scrubber: some View {
        HStack {
            Slider(value: $seconds, in: 0...max(render.seconds, 1)) { editing in
                if !editing { render.release(at: seconds) }
            }
            .onChange(of: seconds) { _, seconds in render.scrub(to: seconds) }
            Text(Self.time(seconds)).monospacedDigit()
        }
    }

    private var clipRow: some View {
        HStack {
            Text("Clip from")
            secondsField(value: $start)
            Text("to")
            secondsField(value: $end)
            Button("From Here") {
                start = render.shownSeconds
                end = min(start + TrackRender.clipSeconds, render.seconds)
            }
            Picker("Frame Rate", selection: $fps) {
                ForEach(ClipPlan.frameRates, id: \.self) { Text("\($0) fps").tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            if let written = render.written {
                ProgressView(value: Double(written), total: Double(max(frames, 1)))
                Button("Cancel", role: .cancel) { render.cancelClip() }
            }
        }
    }

    private func secondsField(value: Binding<Double>) -> some View {
        TextField("Seconds", value: value, format: .number.precision(.fractionLength(0...2)))
            .frame(width: SceneMetrics.secondsFieldWidth)
            .help("Seconds from the track's start")
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Export Still…", action: exportStill)
                .disabled(!render.canExport)
            Button("Export Clip…", action: exportClip)
                .disabled(!render.canExport || frames == 0)
                .keyboardShortcut(.defaultAction)
        }
    }

    /// The frames the clip as set would hold.
    private var frames: Int {
        guard let source = render.source else { return 0 }
        return ClipPlan(rate: source.rate, fps: fps, start: start, end: min(end, render.seconds))
            .count
    }

    private func chooseTrack() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        seconds = 0
        start = 0
        Task {
            await render.choose(url)
            end = min(TrackRender.clipSeconds, render.seconds)
        }
    }

    private func exportStill() {
        guard let url = Self.destination(named: "\(sceneName).png", type: .png) else { return }
        render.exportStill(to: url)
    }

    private func exportClip() {
        guard let url = Self.destination(named: "\(sceneName).mp4", type: .mpeg4Movie) else {
            return
        }
        render.exportClip(from: start, to: end, fps: fps, at: url)
    }

    private static func destination(named name: String, type: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = name
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// "song.flac · 4:12 · 96 kHz · Stereo".
    private static func describe(_ source: TrackSource, seconds: Double) -> String {
        let channels = source.channels == 1 ? "Mono" : "Stereo"
        return [source.name, time(seconds), RateText.text(source.rate), channels]
            .joined(separator: " · ")
    }

    private static func time(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}

/// Starts nothing: a preview runs a copy of the app that must start no helper (`pitfalls.md`).
private struct NoHelper: HelperLauncher {
    func launch() throws -> any RunningHelper { throw HelperLocation.Missing.script }
}

#Preview("Before a track is chosen") {
    TrackRenderSheet(
        sceneName: "RTA",
        render: TrackRender(
            helper: RenderHelper(launcher: NoHelper()), scene: .object([:]), builtIn: true,
            context: RenderContext(
                display: PixelSize(width: 1920, height: 720), viewing: .object([:]),
                images: URL(filePath: "/tmp")),
            rates: [44_100, 48_000, 88_200, 96_000, 192_000]))
}
