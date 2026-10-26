import Charts
import SwiftUI

struct StorageCard: View {
    let current: StorageSnapshot
    let history: [StorageSnapshot]

    private func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pamięć urządzenia")
                    .font(.subheadline.weight(.heavy))
                Spacer()
                Text("Wolne: \(format(current.freeBytes))")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.accent)
            }
            ProgressView(value: Double(current.usedBytes), total: Double(max(current.totalBytes, 1)))
                .progressViewStyle(CapsuleBarStyle(fill: .primary.opacity(0.78)))
            Text("Zajęte \(format(current.usedBytes)) z \(format(current.totalBytes))")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)

            if history.count >= 2 {
                Chart(history, id: \.date) { snapshot in
                    LineMark(
                        x: .value("Data", snapshot.date, unit: .day),
                        y: .value("Zajęte", Double(snapshot.usedBytes) / 1e9)
                    )
                    .foregroundStyle(.accent)
                }
                .chartYAxisLabel { Text(verbatim: "GB") }
                .frame(height: 50)
            }
        }
        .card(padding: 16)
    }
}
