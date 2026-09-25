import Photos
import SwiftUI

struct ResultsView: View {
    @Bindable var flow: DeleteFlow
    @State private var selectedTab: TrainingDataStore.Label = .delete
    @State private var showConfirm = false
    @State private var showUncertainReview = false

    private var deleteItems: [ClassifiedAsset] { flow.classified.filter { $0.label == .delete } }
    private var keepItems: [ClassifiedAsset] { flow.classified.filter { $0.label == .keep } }
    private var uncertainDeleteItems: [ClassifiedAsset] {
        deleteItems
            .filter { $0.confidence < DeleteFlow.uncertaintyThreshold }
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

            if selectedTab == .delete, !uncertainDeleteItems.isEmpty {
                Button {
                    showUncertainReview = true
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
                            isUncertain: selectedTab == .delete && item.confidence < DeleteFlow.uncertaintyThreshold
                        ) {
                            flow.moveAsset(item, to: selectedTab == .delete ? .keep : .delete)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            Button(role: .destructive) {
                showConfirm = true
            } label: {
                Text("Usuń \(deleteItems.count) zdjęć")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(deleteItems.isEmpty)
            .padding()
        }
        .confirmationDialog(
            "Usunąć \(deleteItems.count) zdjęć?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Usuń", role: .destructive) { flow.confirmDeletion() }
            Button("Anuluj", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showUncertainReview) {
            UncertainReviewView(flow: flow, items: uncertainDeleteItems)
        }
    }
}

private struct ThumbnailCell: View {
    let item: ClassifiedAsset
    let isUncertain: Bool
    let onTapMove: () -> Void

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
            if isUncertain {
                Image(systemName: "questionmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white, .orange)
                    .padding(4)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: item.label == .delete ? "arrow.uturn.backward.circle.fill" : "trash.circle.fill")
                .font(.title3)
                .foregroundStyle(.white, .black.opacity(0.6))
                .padding(4)
        }
        .onTapGesture(perform: onTapMove)
        .task {
            image = await PhotoLibraryService.requestImage(
                for: item.asset, targetSize: CGSize(width: 200, height: 200)
            )
        }
    }
}
