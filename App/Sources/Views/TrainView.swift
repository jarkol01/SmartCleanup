import SwiftUI

struct TrainView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow = TrainFlow()

    var body: some View {
        NavigationStack {
            Group {
                switch flow.stage {
                case .requestingAccess:
                    ToolIntroView(intro: .train) {
                        Button("Zacznij oznaczać") {
                            Haptics.selection()
                            Task { await flow.start() }
                        }
                        .buttonStyle(.primary)
                    }

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
                        .buttonStyle(.primary)
                        .padding(18)
                    }
                }
            }
            .screenBackground()
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

extension ToolIntro {
    static var train: ToolIntro {
        let (keep, delete) = TrainingDataStore.sampleCounts()
        return ToolIntro(
            title: "Ucz model",
            systemImage: "brain.head.profile",
            lead: "Pokaż modelowi, które zdjęcia zachowujesz, a które usuwasz. Na tej podstawie zaproponuje sprzątanie.",
            badge: Text("\(keep + delete) przykładów · \(keep) Zachowaj / \(delete) Usuń"),
            steps: [
                ("hand.point.right", "**Przeciągnij w prawo**, żeby zachować."),
                ("hand.point.left", "**Przeciągnij w lewo**, żeby usunąć."),
                ("forward", "**Trudno ocenić?** Pomiń zdjęcie."),
                ("3.circle", "**Co najmniej 3 z każdej kategorii.** Model douczy się przy następnym „Usuń zdjęcia”."),
            ],
            infos: [
                InfoRow(systemImage: "lightbulb", text: "Przydaje się głównie na początku. Później model uczy się sam z Twoich decyzji w „Usuń zdjęcia”.", fill: .card),
                InfoRow(systemImage: "checkmark.shield", text: "Tutaj nic nie jest usuwane, tylko uczysz model."),
            ]
        )
    }
}
