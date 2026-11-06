import ConsoleCore
import SwiftUI

/// The panel picker, in the Panel page's toolbar (`panel-window`): the title Panel, bold and on no
/// glass, then a menu named for the panel held, marked discovered while it was found and is not
/// paired (discovery design D11). Two items, since a menu sharing an item with its title is drawn
/// over it. It takes plain values, so previews can show each case.
struct PanelPicker: ToolbarContent {
    let panel: PanelLabel?
    /// The panels found on the network but the one held.
    let others: [FoundPanel]
    /// False while macOS refuses the app the local network.
    let mayBrowse: Bool
    let choose: (FoundPanel) -> Void
    let addPanel: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Text("Panel:").font(.headline)
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .navigation) {
            Menu {
                PanelPickerItems(picker: self)
            } label: {
                title.padding(.horizontal, PanelMetrics.pickerLabelPadding)
            }
        }
    }

    private var title: Text {
        guard let panel else { return Text("None") }
        return panel.isDiscovered
            ? Text("\(panel.name) (discovered)") : Text(verbatim: panel.name)
    }
}

/// The picker's menu: the panel held, then the others found, then Add Panel… (discovery design D8).
struct PanelPickerItems: View {
    let picker: PanelPicker

    var body: some View {
        if let panel = picker.panel { Text(verbatim: panel.name) }
        Section("On the Network") {
            if !picker.mayBrowse {
                Text(
                    """
                    This app may not reach the local network. Allow it in System Settings > \
                    Privacy & Security > Local Network.
                    """)
            } else if picker.others.isEmpty {
                Text("No other panels found")
            } else {
                ForEach(picker.others) { found in
                    Button {
                        picker.choose(found)
                    } label: {
                        Text(verbatim: found.listedName)
                    }
                }
            }
        }
        Divider()
        Button("Add Panel…", action: picker.addPanel)
    }
}

/// The picker where the window puts it, beside a sidebar, with its menu's items laid out flat
/// below, since a preview cannot open the menu.
private struct PickerPreview: View {
    let panel: PanelLabel?
    var others: [FoundPanel] = []
    var mayBrowse = true

    var body: some View {
        let picker = PanelPicker(
            panel: panel, others: others, mayBrowse: mayBrowse, choose: { _ in }, addPanel: {})
        NavigationSplitView {
            List { Label("Panel", systemImage: "gauge.with.dots.needle.33percent") }
        } detail: {
            Form { Section("Menu") { PanelPickerItems(picker: picker) } }
                .formStyle(.grouped)
                .navigationTitle("Panel")
                .toolbar { picker }
                .toolbar(removing: .title)
        }
    }
}

#Preview("Discovered") {
    PickerPreview(panel: PanelLabel(name: "audio-vue.local", isDiscovered: true))
}

#Preview("Paired, two found") {
    PickerPreview(
        panel: PanelLabel(name: "audio-vue", isDiscovered: false),
        others: [
            FoundPanel(id: "c", name: "cabin", address: HostAddress(parsing: "cabin.local")),
            FoundPanel(id: "s", name: "studio", address: nil),
        ])
}

#Preview("None, denied") { PickerPreview(panel: nil, mayBrowse: false) }
