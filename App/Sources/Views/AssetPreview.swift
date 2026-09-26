import Photos
import SwiftUI

/// Full-size long-press preview shared by every review grid's `.contextMenu(preview:)` —
/// fetched separately from the small grid thumbnail since "zobaczyć szczegóły" needs real
/// resolution, not an upscaled 100x100/200x200 thumbnail.
struct AssetPreview: View {
    let asset: PHAsset

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ProgressView().frame(width: 200, height: 200)
            }
        }
        .task {
            image = await PhotoLibraryService.requestImage(
                for: asset, targetSize: PHImageManagerMaximumSize
            )
        }
    }
}
