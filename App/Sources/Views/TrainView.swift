import SwiftUI

struct TrainView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow = TrainFlow()

    var body: some View {
        NavigationStack {
            Group {
                switch flow.stage {
                case .requestingAccess:
                    ProgressView("Proszę o dostęp do zdjęć…")
                        .task { await flow.start() }

                case .accessDenied:
                    ContentUnavailableView(
                        "Brak dostępu do zdjęć",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("Włącz dostęp do zdjęć w Ustawieniach, aby korzystać z aplikacji.")
                    )

                case .swiping:
                    SwipeView(assets: flow.pool, onFinished: flow.finishSwiping)

                case .training:
                    ProgressView("Trenuję model na urządzeniu…")

                case .done:
                    ContentUnavailableView(
                        "Model zaktualizowany",
                        systemImage: "checkmark.circle",
                        description: Text("Model nauczył się Twoich preferencji.")
                    )
                    .safeAreaInset(edge: .bottom) {
                        Button("Wróć do menu") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .padding()
                    }
                }
            }
            .navigationTitle("Ucz model")
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
