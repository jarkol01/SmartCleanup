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

                case .done:
                    ContentUnavailableView(
                        "Zapisano",
                        systemImage: "checkmark.circle",
                        description: Text("Model zaktualizuje się automatycznie, gdy następnym razem zaczniesz sprzątać zdjęcia.")
                    )
                    .safeAreaInset(edge: .bottom) {
                        Button("Wróć do menu") {
                            Haptics.selection()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                }
            }
            .navigationTitle("Ucz model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
        }
    }
}
