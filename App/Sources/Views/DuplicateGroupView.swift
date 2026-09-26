import Photos
import SwiftUI

/// One group of near-duplicate photos as a single gallery — any number of assets, including
/// zero (deleting the whole group) or all of them (keeping the whole group), can be marked
/// "keep"; the rest are implicitly "delete". Bursts can run into the dozens, so this is a
/// scrollable adaptive grid, not a fixed 2-4 photo layout.
struct DuplicateGroupView: View {
    let flow: DuplicateReviewFlow
    let group: DuplicateGroup
    let groupNumber: Int
    let totalGroups: Int

    var body: some View {
        VStack(spacing: 0) {
            Text("Grupa \(groupNumber)/\(totalGroups) · \(group.assets.count) zdjęć")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 4)], spacing: 4) {
                    ForEach(group.assets, id: \.localIdentifier) { asset in
                        DuplicateThumbnailCell(
                            asset: asset,
                            isKept: flow.isKept(asset),
                            onTap: { flow.toggle(asset) }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)
            }

            if flow.deleteCount > 0 {
                // Same hold-to-confirm as ResultsView's and BlurReviewView's destructive delete.
                HoldToConfirmButton(
                    duration: 0.7,
                    tint: .red,
                    action: { flow.confirmCurrentGroup() }
                ) {
                    Text("Usuń \(flow.deleteCount), zostaw \(flow.keepCount)")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .padding()
            } else {
                Button {
                    Haptics.selection()
                    flow.confirmCurrentGroup()
                } label: {
                    Text("Usuń \(flow.deleteCount), zostaw \(flow.keepCount)")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
    }
}

private struct DuplicateThumbnailCell: View {
    let asset: PHAsset
    let isKept: Bool
    let onTap: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(.gray.opacity(0.2))
            }
        }
        .frame(width: 100, height: 100)
        .clipped()
        .overlay {
            if isKept {
                RoundedRectangle(cornerRadius: 4).stroke(.green, lineWidth: 3)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isKept {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .green)
                    .padding(4)
            }
        }
        .onTapGesture {
            Haptics.selection()
            onTap()
        }
        .contextMenu {
            // An empty menu here disables the long-press entirely on-device, so this mirrors
            // the tap action instead of leaving the menu section empty.
            Button {
                Haptics.selection()
                onTap()
            } label: {
                Label(
                    isKept ? "Oznacz do usunięcia" : "Oznacz do zachowania",
                    systemImage: isKept ? "trash" : "checkmark.circle"
                )
            }
        } preview: {
            // Same native long-press preview as ResultsView's ThumbnailCell.
            AssetPreview(asset: asset)
        }
        .task {
            image = await PhotoLibraryService.requestImage(
                for: asset, targetSize: CGSize(width: 200, height: 200)
            )
        }
    }
}
