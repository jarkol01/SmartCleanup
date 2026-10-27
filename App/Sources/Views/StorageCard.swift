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
                chart.padding(.top, 8)
            }
        }
        .card(padding: 16)
    }

    /// Plots free space (same number as "Wolne") so freeing space makes the line rise.
    /// Y range hugs the data with few marks; a 0–max range squashes daily changes into a flat line.
    private var chart: some View {
        let free = history.map { Double($0.freeBytes) / 1e9 }
        let pad = max((free.max()! - free.min()!) * 0.25, 1)
        return Chart(history, id: \.date) { snapshot in
            LineMark(
                x: .value("Data", snapshot.date, unit: .day),
                y: .value("Wolne", Double(snapshot.freeBytes) / 1e9)
            )
            .foregroundStyle(.accent)
            .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        }
        .chartYScale(domain: (free.min()! - pad)...(free.max()! + pad))
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxisLabel { Text("Wolne, GB") }
        .frame(height: 110)
    }
}
