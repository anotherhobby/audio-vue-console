import SwiftUI

@main struct AudioVueConsoleApp: App {
    #if DEBUG
        /// The sketch's scenes as edited, kept here so they outlive the sketch's window.
        @State private var sceneStore = SceneStore()
    #endif

    var body: some Scene {
        WindowGroup {
            ConnectView()
        }
        #if DEBUG
            // The UI sketch, in the Window menu, around the scene canvas. Its Arrange menu acts on
            // the canvas, the one place it applies.
            Window("UI Sketch", id: "sketch") {
                SketchShell()
                    .environment(sceneStore)
            }
            .defaultSize(
                width: SketchMetrics.windowDefaultWidth, height: SketchMetrics.windowDefaultHeight
            )
            .commands { ArrangeCommands() }
        #endif
    }
}
