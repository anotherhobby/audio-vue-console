import SwiftUI

@main struct AudioVueConsoleApp: App {
    var body: some Scene {
        WindowGroup {
            ConnectView()
        }
        #if DEBUG
            // The throwaway UI sketch, in the Window menu, until the canvas spike replaces it.
            Window("UI Sketch", id: "sketch") {
                SketchShell()
            }
            .defaultSize(
                width: SketchMetrics.windowDefaultWidth, height: SketchMetrics.windowDefaultHeight)
        #endif
    }
}
