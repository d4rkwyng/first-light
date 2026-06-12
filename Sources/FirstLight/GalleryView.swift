import SwiftUI

/// Real Apple-1s, photographed in the museums where they live now.
/// All images are CC BY-SA from Wikimedia Commons; credits below each.
struct GalleryPhoto: Identifiable {
    let file: String
    let title: String
    let caption: String
    let credit: String

    var id: String { file }
}

enum Gallery {
    static let photos: [GalleryPhoto] = [
        GalleryPhoto(
            file: "woz-board-chm",
            title: "Woz's own Apple-1",
            caption: "Steve Wozniak's personal Apple-1 at the Computer "
                + "History Museum — the very board this app's layout is "
                + "drawn from. Note the white DRAMs bottom-right, the "
                + "white-and-gold 6502, and the blue Sprague capacitors.",
            credit: "Photo: Arnold Reinhold, CC BY-SA 4.0, Wikimedia Commons"),
        GalleryPhoto(
            file: "smithsonian-case",
            title: "The Smithsonian's Apple-1",
            caption: "An owner-built wooden case with the keyboard set in — "
                + "the machine Apple never gave a body, given one at home. "
                + "\"APPLE\" is cut by hand into the back panel.",
            credit: "Photo: Ed Uthman, CC BY-SA 2.0, Wikimedia Commons"),
        GalleryPhoto(
            file: "board-case-chm",
            title: "In its wooden tray",
            caption: "Another survivor at the Computer History Museum, "
                + "bare board in a shallow wood case. For $666.66 this is "
                + "everything that came in the box — the box was optional "
                + "too.",
            credit: "Photo: Jordiipa, CC BY-SA 3.0, Wikimedia Commons"),
        GalleryPhoto(
            file: "setup-hnf",
            title: "A complete 1976 setup",
            caption: "Board, third-party keyboard, and a television — an "
                + "Apple-1 as its owner actually used it, at the Heinz "
                + "Nixdorf MuseumsForum in Germany.",
            credit: "Photo: Sergei Magel/HNF, CC BY-SA 4.0, Wikimedia Commons"),
    ]
}

struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    var body: some View {
        let photo = Gallery.photos[index]
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 10) {
                    RainbowApple().frame(width: 18, height: 21)
                    Text("The Real Apple-1")
                }
                    .font(.system(size: 18, weight: .bold, design: .serif))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            if let url = Bundle.module.url(forResource: photo.file,
                                           withExtension: "jpg",
                                           subdirectory: "Resources/Gallery"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(maxWidth: 760, maxHeight: 480)
            }

            HStack(alignment: .top, spacing: 14) {
                Button {
                    index = (index + Gallery.photos.count - 1) % Gallery.photos.count
                } label: {
                    Image(systemName: "chevron.left").padding(6)
                }
                VStack(spacing: 5) {
                    Text(photo.title).font(.system(size: 14, weight: .semibold))
                    Text(photo.caption)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(photo.credit)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text("\(index + 1) of \(Gallery.photos.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                Button {
                    index = (index + 1) % Gallery.photos.count
                } label: {
                    Image(systemName: "chevron.right").padding(6)
                }
            }
        }
        .padding(20)
        .frame(width: 820)
    }
}
