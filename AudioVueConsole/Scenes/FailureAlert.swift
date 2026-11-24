import SwiftUI

extension View {
    /// An alert titled `title` while `reason` holds why something failed, cleared when dismissed.
    func failureAlert(_ title: String, reason: Binding<String?>) -> some View {
        alert(
            title,
            isPresented: Binding(
                get: { reason.wrappedValue != nil }, set: { _ in reason.wrappedValue = nil })
        ) {
            Button("OK") { reason.wrappedValue = nil }
        } message: {
            Text(reason.wrappedValue ?? "")
        }
    }
}
