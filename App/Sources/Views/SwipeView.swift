import Photos
import SwiftUI

/// Open-ended swipe deck: the caller decides when to stop via the "Zakończ" button
/// rather than the deck running out (the pool can be the whole library).
struct SwipeView: View {
    let assets: [PHAsset]
    let onFinished: () -> Void

    private enum Decision {
        case labeled(TrainingDataStore.Label)
        case skipped
    }

    @State private var index = 0
    @State private var imageCache: [String: UIImage] = [:]
    @State private var dragOffset: CGSize = .zero
    @State private var history: [(asset: PHAsset, decision: Decision)] = []

    private var currentImage: UIImage? {
        guard index < assets.count else { return nil }
        return imageCache[assets[index].localIdentifier]
    }

    private var labeledCount: Int {
        history.filter { if case .labeled = $0.decision { true } else { false } }.count
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    undo()
                } label: {
                    Label("Cofnij", systemImage: "arrow.uturn.backward.circle.fill")
                }
                .disabled(history.isEmpty)

                Spacer()

                Text("Oznaczono: \(labeledCount)")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Zakończ") { onFinished() }
            }

            GeometryReader { geo in
                ZStack {
                    if let currentImage {
                        SwipeCard(image: currentImage, dragOffset: dragOffset)
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else if index < assets.count {
                        ProgressView()
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        ContentUnavailableView(
                            "To wszystkie zdjęcia",
                            systemImage: "photo.stack",
                            description: Text("Kliknij \"Zakończ\", żeby wytrenować model.")
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .gesture(
                    DragGesture()
                        .onChanged { dragOffset = $0.translation }
                        .onEnded(handleDragEnded)
                )
            }

            Text("Przeciągnij w prawo, żeby zachować, w lewo, żeby usunąć")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Pomiń — trudno ocenić") { skip() }
                .font(.footnote)
                .disabled(index >= assets.count)
                .padding(.bottom, 8)
        }
        .padding()
        .task(id: index) { await loadCurrentAndPreloadAhead() }
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
        guard index < assets.count, let currentImage else { return }
        let asset = assets[index]
        TrainingDataStore.save(currentImage, assetIdentifier: asset.localIdentifier, as: label)
        history.append((asset, .labeled(label)))
        Haptics.impact(label == .keep ? .light : .medium)

        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = CGSize(width: label == .keep ? 500 : -500, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dragOffset = .zero
            index += 1
        }
    }

    private func skip() {
        guard index < assets.count else { return }
        history.append((assets[index], .skipped))
        index += 1
    }

    private func undo() {
        guard let last = history.popLast() else { return }
        if case .labeled(let label) = last.decision {
            TrainingDataStore.remove(assetIdentifier: last.asset.localIdentifier, label: label)
        }
        dragOffset = .zero
        index -= 1
    }

    /// Loads the current photo, then kicks off loading the next couple in the background
    /// so the swipe never has to wait once the user reaches them.
    private func loadCurrentAndPreloadAhead() async {
        guard index < assets.count else { return }
        await ensureLoaded(assets[index])
        Task {
            for offset in 1...2 {
                let i = index + offset
                guard i < assets.count else { continue }
                await ensureLoaded(assets[i])
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
