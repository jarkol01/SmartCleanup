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
            HStack {
                Label("Pamięć urządzenia", systemImage: "iphone")
                    .font(.subheadline.bold())
                Spacer()
                Text("Wolne: \(format(current.freeBytes))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(current.usedBytes), total: Double(max(current.totalBytes, 1)))
            Text("Zajęte \(format(current.usedBytes)) z \(format(current.totalBytes))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if history.count >= 2 {
                Chart(history, id: \.date) { snapshot in
                    LineMark(
                        x: .value("Data", snapshot.date, unit: .day),
                        y: .value("Zajęte", Double(snapshot.usedBytes) / 1e9)
                    )
                }
                .chartYAxisLabel { Text(verbatim: "GB") }
                .frame(height: 60)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
