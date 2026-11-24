import SwiftUI

/// A page not built yet, named for its section.
struct SketchLaterPage: View {
    let section: PanelSection

    var body: some View {
        ContentUnavailableView(
            section.title, systemImage: section.symbol,
            description: Text("Not sketched yet."))
    }
}
