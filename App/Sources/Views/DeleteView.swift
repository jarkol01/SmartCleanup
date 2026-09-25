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
                    BatchSizePickerView(
                        availableCount: flow.unhandledCount,
                        onPick: { flow.classifyBatch(size: $0) }
                    )

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
            .navigationTitle("Usuń zdjęcia")
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

            Button("Kontynuuj", action: onContinue)
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 24)
        }
        .padding()
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct BatchSizePickerView: View {
    let availableCount: Int
    let onPick: (Int) -> Void

    private var options: [Int] { [50, 100, 250, 500].filter { $0 < availableCount } }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Ile zdjęć przejrzeć teraz?")
                .font(.title2.bold())
            Text("Zostało \(availableCount) nieprzejrzanych zdjęć. Możesz przerobić je partiami zamiast wszystkie naraz.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                ForEach(options, id: \.self) { count in
                    Button("\(count) zdjęć") { onPick(count) }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
                Button("Wszystkie (\(availableCount))") { onPick(availableCount) }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}
