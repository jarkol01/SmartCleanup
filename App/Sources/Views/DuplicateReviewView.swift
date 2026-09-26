import SwiftUI

/// Top-level stage-machine view for "Usuń duplikaty" — mirrors DeleteView's shape (a Group
/// switching on the flow's stage) but reviews one duplicate group at a time instead of one flat
/// keep/delete grid.
struct DuplicateReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow = DuplicateReviewFlow()

    private var canRescan: Bool {
        switch flow.stage {
        case .reviewing, .noDuplicates, .done: true
        default: false
        }
    }

    var body: some View {
        NavigationStack {
            Group {
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

                case .done(let deletedCount, let groupsReviewed):
                    ContentUnavailableView(
                        "Gotowe",
                        systemImage: "checkmark.circle",
                        description: Text("Przejrzano \(groupsReviewed) grup, usunięto \(deletedCount) zdjęć.")
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
            .navigationTitle("Usuń duplikaty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") {
                        Haptics.selection()
                        dismiss()
                    }
                }
                if canRescan {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skanuj ponownie") {
                            Haptics.selection()
                            flow.rescan()
                        }
                    }
                }
            }
        }
        .task { await flow.start() }
    }
}
