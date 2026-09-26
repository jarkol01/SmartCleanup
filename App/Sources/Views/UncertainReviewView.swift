import Photos
import SwiftUI

/// A short, focused swipe pass over only the low-confidence "delete" predictions —
/// lets a cautious user double-check the borderline cases without reviewing everything.
struct UncertainReviewView: View {
    let flow: DeleteFlow
    let items: [ClassifiedAsset]

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var imageCache: [String: UIImage] = [:]
    @State private var dragOffset: CGSize = .zero

    private var currentItem: ClassifiedAsset? {
        index < items.count ? items[index] : nil
    }
    private var currentImage: UIImage? {
        guard let currentItem else { return nil }
        return imageCache[currentItem.id]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Niepewne: \(min(index + 1, items.count))/\(items.count)")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack {
                        if let currentItem {
                            if let currentImage {
                                SwipeCard(image: currentImage, dragOffset: dragOffset)
                            } else {
                                ProgressView()
                            }
                        } else {
                            ContentUnavailableView(
                                "Gotowe",
                                systemImage: "checkmark.circle",
                                description: Text("Sprawdzono wszystkie niepewne zdjęcia.")
                            )
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .gesture(
                        DragGesture()
                            .onChanged { dragOffset = $0.translation }
                            .onEnded(handleDragEnded)
                    )
                }

                Text("Model chce to usunąć. Przeciągnij w prawo, żeby jednak zachować, w lewo, żeby potwierdzić.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .task(id: index) { await loadCurrentAndPreloadAhead() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        let threshold: CGFloat = 100
        if value.translation.width > threshold {
            decide(.keep)
        } else if value.translation.width < -threshold {
            decide(.delete)
        } else {
            withAnimation(.spring) { dragOffset = .zero }
        }
    }

    private func decide(_ label: TrainingDataStore.Label) {
        guard let currentItem else { return }
        flow.moveAsset(currentItem, to: label)
        Haptics.impact(label == .keep ? .light : .medium)

        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = CGSize(width: label == .keep ? 500 : -500, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dragOffset = .zero
            index += 1
            if index >= items.count { dismiss() }
        }
    }

    private func loadCurrentAndPreloadAhead() async {
        guard let currentItem else { return }
        await ensureLoaded(currentItem.asset)
        Task {
            for offset in 1...2 {
                let i = index + offset
                guard i < items.count else { continue }
                await ensureLoaded(items[i].asset)
            }
        }
    }

    private func ensureLoaded(_ asset: PHAsset) async {
        guard imageCache[asset.localIdentifier] == nil else { return }
        if let image = await PhotoLibraryService.requestImage(
            for: asset, targetSize: CGSize(width: 800, height: 800)
        ) {
            imageCache[asset.localIdentifier] = image
        }
    }
}
