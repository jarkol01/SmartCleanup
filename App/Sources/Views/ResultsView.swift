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
                }
                .buttonStyle(CapsuleButtonStyle(fill: .warning, foreground: .onWarning))
                .padding(.horizontal)
                .padding(.bottom, 10)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
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
                .padding(.horizontal, 12)
            }
            .id(selectedTab)  // fresh scroll position per tab, so a short tab never opens scrolled past its end

            if deleteItems.isEmpty {
                // Nothing to confirm-delete, but the batch's Keep decisions still need to be
                // saved as training data and marked handled so they don't resurface next batch.
                Button("Zakończ partię (wszystko zachowane)") {
                    Haptics.selection()
                    flow.confirmDeletion()
                }
                .buttonStyle(.primary)
                .disabled(flow.classified.isEmpty)
                .padding()
            } else {
                // Hold-to-confirm instead of a tap + dialog: a deliberate ~0.7s hold is at
                // least as hard to trigger by accident, with no second UI to maintain.
                HoldToConfirmButton(title: "Usuń \(deleteItems.count) zdjęć", isDisabled: flow.classified.isEmpty, action: { flow.confirmDeletion() })
                .padding()
            }
        }
        .screenBackground()
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

    var body: some View {
        AssetThumbnail(asset: item.asset)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 4) {
                if isUncertain { UncertainChip() }
                if item.isException {
                    IconCircle(systemImage: "star.fill", size: 22, fill: .white, foreground: .onWarning)
                }
            }
            .padding(6)
        }
        .overlay(alignment: .bottomTrailing) {
            IconCircle(systemImage: item.label == .delete ? "arrow.uturn.backward" : "trash", size: 26, fill: .white, foreground: .black.opacity(0.75))
                .padding(.trailing, 6)
                .padding(.bottom, 16)
        }
        .overlay(alignment: .bottom) {
            if !item.isUserOverridden {
                ScoreBar(value: item.confidence, tint: item.label == .delete ? .destructive : .accent)
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
            AssetPreview(asset: item.asset)
        }
    }
}
