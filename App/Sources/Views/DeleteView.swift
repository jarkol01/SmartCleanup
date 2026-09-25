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
                        Button("Wróć do menu") { dismiss() }
                            .buttonStyle(.borderedProminent)
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
