import Photos
import SwiftUI

private struct UncertainReviewPayload: Identifiable {
    let id = UUID()
    let items: [ClassifiedAsset]
}

struct ResultsView: View {
    @Bindable var flow: DeleteFlow
    @State private var selectedTab: TrainingDataStore.Label = .delete
    @State private var uncertainReviewPayload: UncertainReviewPayload?

    /// User-overridden items have a stale confidence (measured for their old label), so they're
    /// pushed to the end instead of being sorted in among the model's own predictions.
    private func sorted(_ items: [ClassifiedAsset]) -> [ClassifiedAsset] {
        items.sorted { !$0.isUserOverridden && $1.isUserOverridden }
    }

    private var deleteItems: [ClassifiedAsset] { sorted(flow.classified.filter { $0.label == .delete }) }
    private var keepItems: [ClassifiedAsset] { sorted(flow.classified.filter { $0.label == .keep }) }
    private var uncertainDeleteItems: [ClassifiedAsset] {
        deleteItems
            .filter { !$0.isUserOverridden && $0.confidence < DeleteFlow.uncertaintyThreshold }
            .sorted { $0.confidence < $1.confidence }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Zakładka", selection: $selectedTab) {
                Text("Do usunięcia (\(deleteItems.count))").tag(TrainingDataStore.Label.delete)
                Text("Do zachowania (\(keepItems.count))").tag(TrainingDataStore.Label.keep)
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedTab) { _, _ in Haptics.selection() }

            if selectedTab == .delete, !uncertainDeleteItems.isEmpty {
                Button {
                    // Freeze the list for this review session — it must not reactively shrink
                    // as flow.classified mutates while the user is mid-swipe (see fullScreenCover below).
                    uncertainReviewPayload = UncertainReviewPayload(items: uncertainDeleteItems)
                } label: {
                    Label("Przejrzyj niepewne (\(uncertainDeleteItems.count))", systemImage: "questionmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 4)], spacing: 4) {
                    ForEach(selectedTab == .delete ? deleteItems : keepItems) { item in
                        ThumbnailCell(
                            item: item,
                            isUncertain: selectedTab == .delete && !item.isUserOverridden
                                && item.confidence < DeleteFlow.uncertaintyThreshold,
                            onTapMove: {
                                flow.moveAsset(item, to: selectedTab == .delete ? .keep : .delete)
                            },
                            onMarkException: {
                                flow.markException(item, as: selectedTab == .delete ? .keep : .delete)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            if deleteItems.isEmpty {
                // Nothing to confirm-delete, but the batch's Keep decisions still need to be
                // saved as training data and marked handled so they don't resurface next batch.
                Button {
                    Haptics.selection()
                    flow.confirmDeletion()
                } label: {
                    Text("Zakończ partię (wszystko zachowane)")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(flow.classified.isEmpty)
                .padding()
            } else {
                // Hold-to-confirm instead of a tap + dialog: a deliberate ~0.7s hold is at
                // least as hard to trigger by accident, with no second UI to maintain.
                HoldToConfirmButton(
                    duration: 0.7,
                    tint: .red,
                    isDisabled: flow.classified.isEmpty,
                    action: { flow.confirmDeletion() }
                ) {
                    Text("Usuń \(deleteItems.count) zdjęć")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .padding()
            }
        }
        .fullScreenCover(item: $uncertainReviewPayload) { payload in
            UncertainReviewView(flow: flow, items: payload.items)
        }
    }
}

private struct ThumbnailCell: View {
    let item: ClassifiedAsset
    let isUncertain: Bool
    let onTapMove: () -> Void
    let onMarkException: () -> Void

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
        .overlay(alignment: .topLeading) {
            HStack(spacing: 2) {
                if isUncertain {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(.white, .orange)
                }
                if item.isException {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(.white, .yellow)
                }
            }
            .font(.caption)
            .padding(4)
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: item.label == .delete ? "arrow.uturn.backward.circle.fill" : "trash.circle.fill")
                .font(.title3)
                .foregroundStyle(.white, .black.opacity(0.6))
                .padding(4)
        }
        .overlay(alignment: .bottom) {
            if !item.isUserOverridden {
                ConfidenceBar(confidence: item.confidence, label: item.label)
            }
        }
        .onTapGesture {
            Haptics.selection()
            onTapMove()
        }
        .contextMenu {
            if item.label == .delete {
                Button {
                    Haptics.notification(.success)
                    onMarkException()
                } label: {
                    Label("Zachowaj na zawsze (wyjątek)", systemImage: "star.fill")
                }
            } else {
                Button {
                    Haptics.notification(.success)
                    onMarkException()
                } label: {
                    Label("Usuń jako wyjątek", systemImage: "star.fill")
                }
            }
        } preview: {
            // Native contextMenu preview: long-press already drives this, so it coexists with
            // onTapGesture (tap) and the menu items above without a second gesture recognizer.
            ThumbnailPreview(asset: item.asset)
        }
        .task {
            image = await PhotoLibraryService.requestImage(
                for: item.asset, targetSize: CGSize(width: 200, height: 200)
            )
        }
    }
}

/// Full-size image shown by the context menu's long-press preview — fetched separately from
/// the 200x200 grid thumbnail since "zobaczyć szczegóły" needs real resolution.
private struct ThumbnailPreview: View {
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

/// A thin, unobtrusive fill along the bottom edge — width and shade both track confidence
/// so it reads at a glance without a number competing with the photo.
private struct ConfidenceBar: View {
    let confidence: Double
    let label: TrainingDataStore.Label

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(.black.opacity(0.15))
                Rectangle()
                    .fill(label == .delete ? Color.red : Color.green)
                    .opacity(0.35 + confidence * 0.45)
                    .frame(width: geo.size.width * confidence)
            }
        }
        .frame(height: 3)
    }
}
