import Photos
import SwiftUI

/// Parallel to DeleteView/ResultsView but for blur detection — kept as its own small,
/// duplicated screen rather than sharing code with the ML delete flow (see BlurFlow).
struct BlurReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow = BlurFlow()

    var body: some View {
        NavigationStack {
            Group {
                switch flow.stage {
                case .checkingAccess:
                    ProgressView().task { await flow.start() }

                case .accessDenied:
                    ContentUnavailableView(
                        "Brak dostępu do zdjęć",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("Włącz dostęp do zdjęć w Ustawieniach, aby korzystać z aplikacji.")
                    )

                case .noMorePhotos:
                    ContentUnavailableView(
                        "Wszystko przejrzane",
                        systemImage: "checkmark.circle",
                        description: Text("Nie ma już nowych zdjęć do przejrzenia w tej bibliotece.")
                    )

                case .pickingBatchSize:
                    BlurBatchSizePickerView(
                        availableCount: flow.unhandledCount,
                        onPick: { flow.scoreBatch(size: $0) }
                    )

                case .scoring(let done, let total):
                    VStack(spacing: 12) {
                        ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                            .padding(.horizontal, 40)
                        Text(total > 0 ? "Analizuję ostrość zdjęć \(done)/\(total)" : "Przygotowuję analizę…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                case .results:
                    BlurResultsView(flow: flow)

                case .deleting:
                    ProgressView("Usuwam zdjęcia…")

                case .done(let count):
                    ContentUnavailableView(
                        "Gotowe",
                        systemImage: "checkmark.circle",
                        description: Text("Usunięto \(count) zdjęć.")
                    )
                    .safeAreaInset(edge: .bottom) {
                        VStack(spacing: 12) {
                            Button("Przetwórz kolejną partię") { flow.reset() }
                                .buttonStyle(.borderedProminent)
                            Button("Wróć do menu") { dismiss() }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Wykryj rozmycie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
            .alert("Błąd", isPresented: Binding(
                get: { flow.errorMessage != nil },
                set: { if !$0 { flow.errorMessage = nil } }
            )) {
                Button("OK") { flow.errorMessage = nil }
            } message: {
                Text(flow.errorMessage ?? "")
            }
        }
    }
}

private struct BlurBatchSizePickerView: View {
    let availableCount: Int
    let onPick: (Int) -> Void

    private var options: [Int] { [50, 100, 250, 500].filter { $0 < availableCount } }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Ile zdjęć przeanalizować teraz?")
                .font(.title2.bold())
            Text("Zostało \(availableCount) nieprzejrzanych zdjęć. Możesz przerobić je partiami zamiast wszystkie naraz.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                ForEach(options, id: \.self) { count in
                    Button("\(count) zdjęć") {
                        Haptics.selection()
                        onPick(count)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                Button("Wszystkie (\(availableCount))") {
                    Haptics.selection()
                    onPick(availableCount)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

private struct BlurResultsView: View {
    @Bindable var flow: BlurFlow
    @State private var selectedTab: BlurLabel = .blurry

    /// Non-overridden items sorted by "how blurry"/"how sharp" they are, overrides pushed to
    /// the end since their score was measured for the label they no longer have.
    private var blurryItems: [BlurredAsset] {
        flow.scored.filter { $0.label == .blurry }.sorted { a, b in
            if a.isUserOverridden != b.isUserOverridden { return !a.isUserOverridden }
            return a.blurScore > b.blurScore
        }
    }
    private var sharpItems: [BlurredAsset] {
        flow.scored.filter { $0.label == .sharp }.sorted { a, b in
            if a.isUserOverridden != b.isUserOverridden { return !a.isUserOverridden }
            return a.blurScore < b.blurScore
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Zakładka", selection: $selectedTab) {
                Text("Rozmyte (\(blurryItems.count))").tag(BlurLabel.blurry)
                Text("Ostre (\(sharpItems.count))").tag(BlurLabel.sharp)
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedTab) { _, _ in Haptics.selection() }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 4)], spacing: 4) {
                    ForEach(selectedTab == .blurry ? blurryItems : sharpItems) { item in
                        BlurThumbnailCell(
                            item: item,
                            isUncertain: !item.isUserOverridden
                                && abs(item.blurScore - BlurFlow.blurThreshold) < 0.1,
                            onTapMove: {
                                flow.moveAsset(item, to: selectedTab == .blurry ? .sharp : .blurry)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            if blurryItems.isEmpty {
                // Nothing to confirm-delete, same non-destructive path as ResultsView.
                Button {
                    Haptics.selection()
                    flow.confirmDeletion()
                } label: {
                    Text("Zakończ partię (wszystko zachowane)")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(flow.scored.isEmpty)
                .padding()
            } else {
                // Same hold-to-confirm as ResultsView's destructive delete button.
                HoldToConfirmButton(
                    duration: 0.7,
                    tint: .red,
                    isDisabled: flow.scored.isEmpty,
                    action: { flow.confirmDeletion() }
                ) {
                    Text("Usuń \(blurryItems.count) zdjęć")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .padding()
            }
        }
    }
}

private struct BlurThumbnailCell: View {
    let item: BlurredAsset
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
                    .foregroundStyle(.white, .orange)
                    .font(.caption)
                    .padding(4)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: item.label == .blurry ? "arrow.uturn.backward.circle.fill" : "trash.circle.fill")
                .font(.title3)
                .foregroundStyle(.white, .black.opacity(0.6))
                .padding(4)
        }
        .overlay(alignment: .bottom) {
            if !item.isUserOverridden {
                BlurScoreBar(score: item.blurScore, label: item.label)
            }
        }
        .onTapGesture {
            Haptics.selection()
            onTapMove()
        }
        .task {
            image = await PhotoLibraryService.requestImage(
                for: item.asset, targetSize: CGSize(width: 200, height: 200)
            )
        }
    }
}

/// Same thin bottom-edge fill as ResultsView's ConfidenceBar, duplicated locally so this
/// screen doesn't reach into ResultsView's private types.
private struct BlurScoreBar: View {
    let score: Double
    let label: BlurLabel

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(.black.opacity(0.15))
                Rectangle()
                    .fill(label == .blurry ? Color.red : Color.green)
                    .opacity(0.35 + score * 0.45)
                    .frame(width: geo.size.width * score)
            }
        }
        .frame(height: 3)
    }
}
