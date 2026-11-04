import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        // The UI sketch for now; the walking skeleton puts the connect view here.
        WindowGroup {
            SketchShell()
        }
        .defaultSize(
            width: SketchMetrics.windowDefaultWidth, height: SketchMetrics.windowDefaultHeight)
    }
}
