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
            HStack(alignment: .bottom) {
                Text("Zajęte \(format(current.usedBytes)) z \(format(current.totalBytes))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if history.count >= 2 {
                    sparkline
                }
            }
        }
        .card(padding: 16)
    }

    /// Trend only, no axes; y range padded to at least 1 GB so a flat history stays a calm line.
    private var sparkline: some View {
        let used = history.map { Double($0.usedBytes) / 1e9 }
        let pad = max((used.max()! - used.min()!) * 0.2, 0.5)
        return Chart(history, id: \.date) { snapshot in
            LineMark(
                x: .value("Data", snapshot.date),
                y: .value("Zajęte", Double(snapshot.usedBytes) / 1e9)
            )
            .foregroundStyle(.accent)
            .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: (used.min()! - pad)...(used.max()! + pad))
        .frame(width: 96, height: 22)
    }
}
