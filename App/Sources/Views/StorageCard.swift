import Charts
import SwiftUI

struct StorageCard: View {
    let current: StorageSnapshot
    let history: [StorageSnapshot]
    @State private var selectedDate: Date?

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

            if let first = history.first, history.count >= 2 {
                HStack(spacing: 4) {
                    Image(systemName: current.freeBytes >= first.freeBytes ? "arrow.up.right" : "arrow.down.right")
                    Text("\(signed(current.freeBytes - first.freeBytes)) od \(first.date.formatted(.dateTime.day().month(.abbreviated)))")
                }
                .font(.footnote.weight(.bold).monospacedDigit())
                .foregroundStyle(.accent)
                .padding(.top, 6)
                chart
            }
        }
        .card(padding: 16)
    }

    private func signed(_ bytes: Int64) -> String {
        (bytes >= 0 ? "+" : "−") + format(abs(bytes))
    }

    /// Free space (same number as "Wolne") as steps: each jump is a real change, e.g. a cleanup.
    /// Y range hugs the data; a 0–max range squashes changes into a flat line.
    private var chart: some View {
        let free = history.map { Double($0.freeBytes) / 1e9 }
        let pad = max((free.max()! - free.min()!) * 0.25, 1)
        let low = free.min()! - pad
        let span = history.last!.date.timeIntervalSince(history.first!.date)
        let days = Int(span / 86_400)
        let selected = selectedDate.flatMap { date in
            history.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        }
        return Chart {
            ForEach(history, id: \.date) { snapshot in
                let gb = Double(snapshot.freeBytes) / 1e9
                AreaMark(x: .value("Data", snapshot.date), yStart: .value("Wolne", low), yEnd: .value("Wolne", gb))
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(.linearGradient(colors: [Color.accent.opacity(0.25), Color.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Data", snapshot.date), y: .value("Wolne", gb))
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            }
            if let point = selected ?? history.last {
                PointMark(x: .value("Data", point.date), y: .value("Wolne", Double(point.freeBytes) / 1e9))
                    .foregroundStyle(.accent)
                    .symbolSize(60)
            }
            if let selected {
                RuleMark(x: .value("Data", selected.date))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 0) {
                            Text(format(selected.freeBytes)).font(.footnote.weight(.heavy).monospacedDigit())
                            Text(selected.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: low...(free.max()! + pad))
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
        .chartXAxis {
            // ponytail: under 2 days label hours, otherwise whole days, so no date repeats on the axis.
            if days < 2 {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            } else {
                AxisMarks(values: .stride(by: .day, count: max(1, days / 4))) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        }
        .chartYAxisLabel { Text("Wolne, GB") }
        .frame(height: 120)
    }
}
