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

                case .noModel:
                    ContentUnavailableView(
                        "Brak wytrenowanego modelu",
                        systemImage: "brain.head.profile",
                        description: Text("Najpierw naucz model w sekcji \"Ucz model\" na ekranie głównym.")
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
