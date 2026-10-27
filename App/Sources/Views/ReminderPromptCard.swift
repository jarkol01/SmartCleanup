import SwiftUI

/// Asks before the system prompt does, at a moment the user just saw the app pay off.
struct ReminderPromptCard: View {
    @State private var isVisible = false

    var body: some View {
        Group {
            if isVisible {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Przypomnieć Ci, gdy uzbiera się nowa porcja?").font(.headline.weight(.heavy))
                    Text("Najwyżej raz w tygodniu, bez spamu.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Tak, przypominaj") {
                            Haptics.selection()
                            isVisible = false
                            Task { await Reminders.enable() }
                        }
                        .buttonStyle(.secondary)
                        Button("Nie teraz") {
                            Haptics.selection()
                            isVisible = false
                            Reminders.declinePrompt()
                        }
                        .foregroundStyle(.secondary)
                    }
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(radius: 16, fill: .card, padding: 14)
            }
        }
        .task { isVisible = await Reminders.shouldOfferPrompt() }
    }
}
