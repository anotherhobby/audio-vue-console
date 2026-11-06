import SwiftUI

/// Sizes for the panel window and its sidebar.
enum PanelMetrics {
    static let windowMinWidth: CGFloat = 900
    static let windowMinHeight: CGFloat = 560
    static let windowDefaultWidth: CGFloat = 1280
    static let windowDefaultHeight: CGFloat = 760

    static let sidebarMinWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 220
    /// Room either side of the panel's name in the picker's capsule.
    static let pickerLabelPadding: CGFloat = 6
}
