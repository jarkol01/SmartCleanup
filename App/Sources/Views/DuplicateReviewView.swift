import SwiftUI

/// Top-level stage-machine view for "Usuń duplikaty" — mirrors DeleteView's shape (a Group
/// switching on the flow's stage) but reviews one duplicate group at a time instead of one flat
/// keep/delete grid.
struct DuplicateReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow = DuplicateReviewFlow()
    @State private var started = false

    private var canRescan: Bool {
        switch flow.stage {
        case .reviewing, .noDuplicates, .done: true
        default: false
        }
    }

    var body: some View {
        Group {
            Group {
                if !started {
                    ToolIntroView(intro: .duplicates) {
                        Button("Rozpocznij skanowanie") {
                            Haptics.selection()
                            started = true
                            Task { await flow.start() }
                        }
                        .buttonStyle(.primary)
                    }
                } else {
                    switch flow.stage {
                    case .accessDenied:
                        ContentUnavailableView(
                            "Brak dostępu do zdjęć",
                            systemImage: "photo.badge.exclamationmark",
                            description: Text("Włącz dostęp do zdjęć w Ustawieniach, aby korzystać z aplikacji.")
                        )

                    case .scanning(let done, let total):
                        VStack(spacing: 12) {
                            ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                                .padding(.horizontal, 40)
                            Text(total > 0 ? "Szukam duplikatów \(done)/\(total)" : "Przygotowuję skanowanie…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                    case .noDuplicates:
                        ContentUnavailableView(
                            "Brak duplikatów",
                            systemImage: "checkmark.circle",
                            description: Text("Nie znaleziono podobnych zdjęć w bibliotece.")
                        )

                    case .reviewing:
                        if let group = flow.currentGroup {
                            DuplicateGroupView(
                                flow: flow,
                                group: group,
                                groupNumber: flow.currentIndex + 1,
                                totalGroups: flow.groups.count
                            )
                        }

                    case .deleting:
                        ProgressView("Usuwam zdjęcia…")

                    case .done(let deletedCount, let groupsReviewed, let freed):
                        DoneView(
                            message: Text("Przejrzano \(groupsReviewed) grup, usunięto \(deletedCount) zdjęć."),
                            freedBytes: freed,
                            infos: [
                                InfoRow(systemImage: "checkmark.shield", text: "Miejsce zwolni się dopiero po opróżnieniu albumu „Ostatnio usunięte”.", fill: .card),
                            ],
                            onMenu: { dismiss() }
                        )
                    }
                }
            }
            .screenBackground()
            .navigationTitle("Usuń duplikaty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if started, canRescan {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skanuj ponownie") {
                            Haptics.selection()
                            flow.rescan()
                        }
                    }
                }
            }
        }
    }
}

extension ToolIntro {
    static var duplicates: ToolIntro {
        ToolIntro(
            title: "Usuń duplikaty",
            systemImage: "square.on.square",
            lead: "Znajduje serie niemal identycznych zdjęć zrobionych w krótkim odstępie, np. zdjęcia seryjne.",
            steps: [
                ("square.stack", "**Po jednej grupie.** Domyślnie zostaje zdjęcie o najwyższej rozdzielczości."),
                ("hand.tap", "**Stuknij** zdjęcie, by zmienić: zostaw albo usuń."),
                ("timer", "**Przytrzymaj**, by powiększyć i porównać szczegóły."),
                ("trash", "**Cała grupa niepotrzebna?** Odznacz wszystkie i usuń ją w całości."),
            ],
            infos: [InfoRow(systemImage: "checkmark.shield", text: "Usunięte zdjęcia trafiają do „Ostatnio usuniętych”.")]
        )
    }
}
