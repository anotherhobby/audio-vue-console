import AppKit
import ConsoleCore
import SwiftUI
import UniformTypeIdentifiers

/// The host's backdrop images by thumbnail, shipped first, then uploads, newest first, and
/// Upload… for a PNG or JPEG from a file, sent as it is. An upload the host refuses says why and
/// chooses nothing (`scene-settings`, "A backdrop image is chosen from the host or uploaded";
/// design D4).
struct ImagePicker: View {
    let scenes: PanelScenes
    /// The image the backdrop holds now, if any.
    let chosen: String?
    let choose: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var images: [HostImage]?
    @State private var failure: String?
    @State private var uploading = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Backdrop Image").font(.headline)
            ScrollView {
                LazyVGrid(columns: Self.columns) {
                    ForEach(images ?? []) { image in
                        ImageTile(image: image, scenes: scenes, isChosen: image.id == chosen) {
                            pick(image.id)
                        }
                    }
                }
            }
            if images == nil, failure == nil { ProgressView() }
            if let failure {
                Text(failure).font(.callout).foregroundStyle(.red)
            }
            HStack {
                Button("Upload…", action: upload).disabled(uploading)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: SceneMetrics.imagePickerWidth, height: SceneMetrics.imagePickerHeight)
        .task { await load() }
    }

    private static let columns = [GridItem(.adaptive(minimum: SceneMetrics.imageThumbnailWidth))]

    private func load() async {
        do throws(HostFailure) {
            images = try await scenes.listImages()
        } catch {
            failure = "The host's images couldn't be read: \(ReadFailureText.text(error))"
        }
    }

    private func pick(_ id: String) {
        choose(id)
        dismiss()
    }

    /// Asks for a PNG or JPEG, then sends its bytes untouched and chooses the stored image.
    private func upload() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            failure = "The file couldn't be read."
            return
        }
        let type: ImageType =
            UTType(filenameExtension: url.pathExtension)?.conforms(to: .png) == true ? .png : .jpeg
        uploading = true
        failure = nil
        Task {
            defer { uploading = false }
            do throws(HostFailure) {
                pick(try await scenes.upload(data, type: type))
            } catch {
                failure = Self.refusal(error)
            }
        }
    }

    private static func refusal(_ failure: HostFailure) -> String {
        if case .imageRefused(let refusal) = failure { return refusal.description }
        return "The upload failed: \(ReadFailureText.text(failure))"
    }
}

/// One of the host's images as a thumbnail, fetched into the app's store, with its size.
struct ImageTile: View {
    let image: HostImage
    let scenes: PanelScenes
    let isChosen: Bool
    let choose: () -> Void
    @State private var thumbnail: NSImage?

    var body: some View {
        Button(action: choose) {
            VStack(spacing: SceneMetrics.settingSpacing) {
                Group {
                    if let thumbnail {
                        Image(nsImage: thumbnail).resizable().scaledToFill()
                    } else {
                        Color.secondary.opacity(SceneMetrics.placeholderOpacity)
                    }
                }
                .frame(
                    width: SceneMetrics.imageThumbnailWidth,
                    height: SceneMetrics.imageThumbnailHeight
                )
                .clipShape(RoundedRectangle(cornerRadius: SceneMetrics.tileCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: SceneMetrics.tileCornerRadius)
                        .stroke(isChosen ? Color.accentColor : .clear, lineWidth: 2)
                }
                Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .task { await load() }
    }

    private var caption: String {
        if image.shipped { return "Ships with audio-vue" }
        guard let width = image.width, let height = image.height else { return "Uploaded" }
        return "\(width) × \(height)"
    }

    private func load() async {
        do throws(HostFailure) {
            thumbnail = try await scenes.imageFile(image.id).flatMap { NSImage(contentsOf: $0) }
        } catch {
            thumbnail = nil
        }
    }
}
