import ConsoleCore
import SwiftUI

/// How a refused scene write reads (design D5, D7): an invalid scene lists each failure by its
/// place, a stale one says the scene changed elsewhere, and anything else names the failure.
enum WriteFailureText {
    static func title(_ failure: HostFailure) -> String {
        switch failure {
        case .invalid: "The Panel Refused This Scene"
        case .stale: "This Scene Was Changed Elsewhere"
        default: "The Scene Wasn't Written"
        }
    }

    static func message(_ failure: HostFailure) -> String {
        switch failure {
        case .invalid(let failures):
            failures.map { "\($0.place.isEmpty ? "The scene" : $0.place): \($0.message)" }
                .joined(separator: "\n")
        case .stale:
            """
            Another client saved this scene after this app read it. Save Over It replaces that \
            change with this one. Discard Mine drops this edit and shows the panel's version.
            """
        case .conflict(let reason): reason
        case .unreachable: "The host couldn't be reached. Your edits are kept."
        case .notFound: "The host no longer has this scene."
        case .tokenRefused: "The host no longer takes this app's pairing. Pair again."
        case .refused, .unexpectedAnswer, .pairingRefused, .unknownClient:
            "The host answered in a way this app didn't expect. Your edits are kept."
        }
    }
}

extension View {
    /// One alert for a refused write. A stale save offers Save Over It, on the host's current
    /// revision, and Discard Mine, where the caller gives them.
    func writeFailureAlert(
        _ failure: Binding<HostFailure?>, saveOver: ((Int) -> Void)? = nil,
        discardMine: (() -> Void)? = nil
    ) -> some View {
        alert(
            failure.wrappedValue.map(WriteFailureText.title) ?? "",
            isPresented: Binding(
                get: { failure.wrappedValue != nil }, set: { if !$0 { failure.wrappedValue = nil } }
            ),
            presenting: failure.wrappedValue
        ) { shown in
            if case .stale(let current) = shown, let saveOver, let discardMine {
                Button("Save Over It") { saveOver(current) }
                Button("Discard Mine", role: .destructive) { discardMine() }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("OK") {}
            }
        } message: { shown in
            Text(WriteFailureText.message(shown))
        }
    }
}

#Preview("An invalid scene's failures") {
    let failure = HostFailure.invalid([
        DocumentFailure(place: "", message: "needs at least one card"),
        DocumentFailure(place: "cards[1].colspan", message: "runs off the grid"),
    ])
    VStack(alignment: .leading, spacing: SceneMetrics.gallerySpacing) {
        Text(WriteFailureText.title(failure)).font(.headline)
        Text(WriteFailureText.message(failure))
    }
    .padding()
}
