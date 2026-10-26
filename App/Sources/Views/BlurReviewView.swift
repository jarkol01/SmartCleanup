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
                    ToolIntroView(intro: .blur) {
                        BatchPicker(
                            title: "Ile zdjęć przeanalizować teraz?",
                            available: flow.unhandledCount,
                            onPick: { flow.scoreBatch(size: $0) }
                        )
                    }

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
                            Button("Przetwórz kolejną partię") {
                                Haptics.selection()
                                flow.reset()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Wróć do menu") {
                                Haptics.selection()
                                dismiss()
                            }
                        }
                        .padding()
                    }
                }
            }
            .screenBackground()
            .navigationTitle("Wykryj rozmycie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") {
                        Haptics.selection()
                        dismiss()
                    }
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

private struct BlurResultsView: View {
    @Bindable var flow: BlurFlow
    @State private var selectedTab: BlurLabel = .blurry
    @State private var showHelp = false

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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                    ForEach(selectedTab == .blurry ? blurryItems : sharpItems) { item in
                        BlurThumbnailCell(
                            item: item,
                            // Margin shrinks as the threshold rises toward 100% — at a stricter
                            // threshold there's less room above it, so "borderline" should mean less.
                            isUncertain: !item.isUserOverridden
                                && abs(item.blurScore - BlurFlow.blurThreshold) < (1 - BlurFlow.blurThreshold) / 2,
                            onTapMove: {
                                flow.moveAsset(item, to: selectedTab == .blurry ? .sharp : .blurry)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }

            if blurryItems.isEmpty {
                // Nothing to confirm-delete, same non-destructive path as ResultsView.
                Button("Zakończ partię (wszystko zachowane)") {
                    Haptics.selection()
                    flow.confirmDeletion()
                }
                .buttonStyle(.primary)
                .disabled(flow.scored.isEmpty)
                .padding()
            } else {
                // Same hold-to-confirm as ResultsView's destructive delete button.
                HoldToConfirmButton(title: "Usuń \(blurryItems.count) zdjęć", isDisabled: flow.scored.isEmpty, action: { flow.confirmDeletion() })
                .padding()
            }
        }
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    showHelp = true
                } label: {
                    Text(verbatim: "?")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.accent)
                        .frame(width: 32, height: 32)
                        .background(Color.card, in: Circle())
                }
                .accessibilityLabel(Text("Jak to działa"))
            }
        }
        .sheet(isPresented: $showHelp) {
            ToolIntroView(intro: .blur).presentationDragIndicator(.visible)
        }
    }
}

private struct BlurThumbnailCell: View {
    let item: BlurredAsset
    let isUncertain: Bool
    let onTapMove: () -> Void

    var body: some View {
        AssetThumbnail(asset: item.asset)
        .overlay(alignment: .topLeading) {
            if isUncertain {
                UncertainChip().padding(6)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            IconCircle(systemImage: item.label == .blurry ? "arrow.uturn.backward" : "trash", size: 26, fill: .white, foreground: .black.opacity(0.75))
                .padding(.trailing, 6)
                .padding(.bottom, 16)
        }
        .overlay(alignment: .bottom) {
            if !item.isUserOverridden {
                ScoreBar(value: item.blurScore, tint: item.label == .blurry ? .destructive : .accent)
            }
        }
        .onTapGesture {
            Haptics.selection()
            onTapMove()
        }
        .contextMenu {
            // An empty menu here disables the long-press entirely on-device, so this mirrors
            // the tap action instead of leaving the menu section empty.
            Button {
                Haptics.selection()
                onTapMove()
            } label: {
                Label(
                    item.label == .blurry ? "Oznacz jako ostre" : "Oznacz jako rozmyte",
                    systemImage: item.label == .blurry ? "arrow.uturn.backward" : "trash"
                )
            }
        } preview: {
            // Same native long-press preview as ResultsView's ThumbnailCell.
            AssetPreview(asset: item.asset)
        }
    }
}

extension ToolIntro {
    static var blur: ToolIntro {
        ToolIntro(
            title: "Wykryj rozmycie",
            systemImage: "camera.aperture",
            lead: "Mierzy ostrość każdego zdjęcia i proponuje usunięcie nieostrych.",
            steps: [
                ("rectangle.bottomthird.inset.filled", "**Pasek** pokazuje, jak bardzo zdjęcie jest rozmyte. Próg zmienisz w Ustawieniach."),
                ("hand.tap", "**Stuknij**, by przerzucić zdjęcie między Rozmyte i Ostre."),
                ("timer", "**Przytrzymaj**, by powiększyć i obejrzeć szczegóły."),
                ("person.crop.rectangle", "**Uwaga:** celowo rozmyte tło (np. portret) też może tu trafić."),
            ],
            infos: [InfoRow(systemImage: "checkmark.shield", text: "Usunięte zdjęcia trafiają do „Ostatnio usuniętych”.")]
        )
    }
}
