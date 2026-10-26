import SwiftUI

struct DeleteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow = DeleteFlow()

    var body: some View {
        NavigationStack {
            Group {
                switch flow.stage {
                case .checkingModel:
                    ProgressView().task { await flow.start() }

                case .notEnoughData:
                    ContentUnavailableView(
                        "Za mało oznaczonych zdjęć",
                        systemImage: "brain.head.profile",
                        description: Text("Oznacz jeszcze kilka zdjęć w sekcji \"Ucz model\" na ekranie głównym — potrzeba co najmniej 3 z każdej kategorii.")
                    )

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
                    let young = ClassifierTrainer.isModelYoung
                    ToolIntroView(intro: .delete) {
                        BatchPicker(
                            title: "Ile zdjęć przejrzeć teraz?",
                            available: flow.unhandledCount,
                            recommendSmall: young,
                            tip: "Na początku przeglądaj małe partie. Model szybciej nauczy się Twoich wyborów.",
                            onPick: { flow.classifyBatch(size: $0) }
                        )
                    }

                case .updatingModel:
                    ProgressView("Aktualizuję model o nowe dane…")

                case .modelUpdated:
                    ModelUpdatedView(
                        result: flow.lastTrainingResult,
                        onContinue: { flow.proceedAfterModelUpdate() }
                    )

                case .classifying(let done, let total):
                    VStack(spacing: 12) {
                        ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                            .padding(.horizontal, 40)
                        Text(total > 0 ? "Klasyfikuję zdjęcia \(done)/\(total)" : "Przygotowuję klasyfikację…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                case .results:
                    ResultsView(flow: flow)

                case .deleting:
                    ProgressView("Usuwam zdjęcia…")

                case .done(let count, let freed):
                    DoneView(
                        message: Text("Usunięto \(count) zdjęć."),
                        freedBytes: freed,
                        infos: [
                            InfoRow(systemImage: "lightbulb", text: "Model douczy się na tych decyzjach przed kolejną partią.", fill: .card),
                            InfoRow(systemImage: "checkmark.shield", text: "Miejsce zwolni się dopiero po opróżnieniu albumu „Ostatnio usunięte”.", fill: .card),
                        ],
                        onNext: { flow.reset() },
                        onMenu: { dismiss() }
                    )
                }
            }
            .screenBackground()
            .navigationTitle("Usuń zdjęcia")
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

/// A dedicated checkpoint after a retrain, separate from the delete-review UI so accuracy
/// numbers don't compete for attention with the actual keep/delete decisions.
private struct ModelUpdatedView: View {
    let result: ClassifierTrainer.TrainingResult?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Model zaktualizowany")
                .font(.title2.bold())

            if let result {
                VStack(spacing: 4) {
                    Text("Dokładność treningowa: \(percent(result.trainingAccuracy))")
                    if let validation = result.validationAccuracy {
                        Text("Dokładność walidacyjna: \(percent(validation))")
                    }
                    if let test = result.testAccuracy {
                        Text("Dokładność testowa: \(percent(test))")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Kontynuuj") {
                Haptics.selection()
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 24)
        }
        .padding()
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

extension ToolIntro {
    static var delete: ToolIntro {
        ToolIntro(
            title: "Usuń zdjęcia",
            systemImage: "trash",
            ai: true,
            lead: "Model nauczony na Twoich decyzjach dzieli zdjęcia na do usunięcia i do zachowania.",
            steps: [
                ("rectangle.bottomthird.inset.filled", "**Pasek** pod zdjęciem pokazuje pewność modelu. Niepewne przejrzysz osobno."),
                ("hand.tap", "**Stuknij**, by przerzucić zdjęcie do drugiej grupy."),
                ("timer", "**Przytrzymaj**, by powiększyć lub oznaczyć wyjątek (np. zdjęcie licznika)."),
                ("lightbulb", "**Twoje decyzje** uczą model. Przed kolejną partią sam się douczy."),
            ],
            infos: [InfoRow(systemImage: "checkmark.shield", text: "Usunięte zdjęcia trafiają do „Ostatnio usuniętych”.")]
        )
    }
}
