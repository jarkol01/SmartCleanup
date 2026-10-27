import SwiftUI
import WidgetKit

struct CleanupEntry: TimelineEntry {
    let date: Date
    let savedBytes: Int64
    let deleted: Int
    let storage: StorageSnapshot?
    let keep: Int
    let delete: Int

    var modelReady: Bool { ModelProgress.isReady(keep: keep, delete: delete) }
    var lowStorage: Bool { (storage?.freeBytes ?? .max) < 5_000_000_000 }

    static func current() -> CleanupEntry {
        let (keep, delete) = ModelProgress.counts
        return CleanupEntry(
            date: .now,
            savedBytes: StatsStore.totalBytesFreedEstimate,
            deleted: StatsStore.totalDeleted,
            storage: StorageStore.current(),
            keep: keep,
            delete: delete
        )
    }

    /// Widget gallery and placeholder.
    static let sample = CleanupEntry(
        date: .now,
        savedBytes: 4_200_000_000,
        deleted: 1342,
        storage: StorageSnapshot(date: .now, totalBytes: 128_000_000_000, freeBytes: 38_400_000_000),
        keep: 236,
        delete: 214
    )
}

struct CleanupProvider: TimelineProvider {
    func placeholder(in context: Context) -> CleanupEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (CleanupEntry) -> Void) {
        completion(context.isPreview ? .sample : .current())
    }

    /// Stats change only in the app, which reloads the widget; the periodic refresh is for free space.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CleanupEntry>) -> Void) {
        completion(Timeline(entries: [.current()], policy: .after(.now.addingTimeInterval(2 * 3600))))
    }
}

@main
struct SmartCleanupWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SmartCleanup", provider: CleanupProvider()) { entry in
            CleanupWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(verbatim: "SmartCleanup"))
        .description("Zwolnione miejsce i szybki dostęp do narzędzi.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct CleanupWidgetView: View {
    let entry: CleanupEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        content
            .fontDesign(.rounded)
            .containerBackground(for: .widget) {
                switch family {
                case .systemSmall, .systemMedium: Color.card
                case .accessoryCircular: AccessoryWidgetBackground()
                default: Color.clear
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .systemMedium: medium
        case .accessoryRectangular: rectangular
        case .accessoryCircular: circular
        case .accessoryInline: inline
        default: small
        }
    }

    // MARK: Home Screen

    private var small: some View {
        Group {
            if entry.modelReady { saved(heroSize: 32) } else { training }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(entry.modelReady ? (entry.lowStorage ? DeepLink.videos.url : nil) : DeepLink.train.url)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            Group {
                if entry.modelReady { saved(heroSize: 30) } else { training }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    tile("Zdjęcia", "trash", .delete)
                    tile("Rozmycie", "camera.aperture", .blur)
                }
                GridRow {
                    tile("Duplikaty", "square.on.square", .duplicates)
                    tile("Wideo", "film", .videos)
                }
            }
            .frame(width: 176)
        }
    }

    /// Saved space up top, free space at the bottom; turns into a warning when space runs low.
    private func saved(heroSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                Text("oszczędzone").font(.footnote.weight(.heavy))
                Text(verbatim: "~\(formatBytes(entry.savedBytes))")
                    .font(.system(size: heroSize, weight: .heavy).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(.accent)
            .widgetAccentable()
            Text("\(Text(entry.deleted, format: .number).bold().foregroundStyle(.primary)) usuniętych")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            if let storage = entry.storage {
                if entry.lowStorage {
                    Label("Mało miejsca", systemImage: "exclamationmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(renderingMode == .fullColor ? Color.onWarning : .primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(renderingMode == .fullColor ? Color.warning : .primary.opacity(0.15), in: Capsule())
                        .padding(.bottom, 4)
                }
                ProgressView(value: Double(storage.usedBytes), total: Double(storage.totalBytes))
                    .progressViewStyle(CapsuleBarStyle(height: 8, fill: .primary.opacity(0.78), trackFill: tileFill))
                Text("Wolne: \(formatBytes(storage.freeBytes))")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
            }
        }
    }

    private var training: some View {
        let needed = ModelProgress.minSamplesPerClass
        return VStack(alignment: .leading, spacing: 6) {
            Text("Zacznij tutaj").chip(renderingMode == .fullColor ? .accentSoft : .primary.opacity(0.15))
            Text("Naucz model, co chcesz usuwać")
                .font(.subheadline.weight(.heavy))
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            ForEach([("Zachowaj", entry.keep), ("Usuń", entry.delete)], id: \.0) { title, count in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(Text(LocalizedStringKey(title))) \(min(count, needed))/\(needed)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(min(count, needed)), total: Double(needed))
                        .progressViewStyle(CapsuleBarStyle(height: 6, trackFill: tileFill))
                        .widgetAccentable()
                }
            }
        }
    }

    private func tile(_ title: LocalizedStringKey, _ systemImage: String, _ link: DeepLink) -> some View {
        Link(destination: link.url) {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 18, weight: .semibold)).foregroundStyle(.accent)
                Text(title).font(.caption.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tileFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// Opaque fills turn into solid white blocks when the system tints the widget.
    private var tileFill: Color {
        renderingMode == .fullColor ? .accentSoft : .primary.opacity(0.15)
    }

    // MARK: Lock Screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("oszczędzone", systemImage: "sparkles").font(.caption.weight(.heavy))
            Text(verbatim: "~\(formatBytes(entry.savedBytes))")
                .font(.title2.weight(.heavy).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            Text("\(Text(entry.deleted, format: .number)) usuniętych").font(.caption.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var circular: some View {
        if let storage = entry.storage {
            Gauge(value: Double(storage.freeBytes), in: 0...Double(storage.totalBytes)) {
                Text(verbatim: "GB")
            } currentValueLabel: {
                Text(Double(storage.freeBytes) / 1e9, format: .number.precision(.fractionLength(0)))
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
            .accessibilityLabel(Text("Wolne: \(formatBytes(storage.freeBytes))"))
        } else {
            Image(systemName: "sparkles").font(.title2)
        }
    }

    @ViewBuilder private var inline: some View {
        if let storage = entry.storage {
            Label("Wolne: \(formatBytes(storage.freeBytes))", systemImage: "sparkles")
        } else {
            Label("Łącznie oszczędzone: ~\(formatBytes(entry.savedBytes))", systemImage: "sparkles")
        }
    }
}

private extension Text {
    func chip(_ fill: Color) -> some View {
        font(.caption.weight(.heavy))
            .textCase(.uppercase)
            .foregroundStyle(.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(fill, in: Capsule())
    }
}

#Preview(as: .systemMedium) {
    SmartCleanupWidget()
} timeline: {
    CleanupEntry.sample
    CleanupEntry(date: .now, savedBytes: 0, deleted: 0, storage: CleanupEntry.sample.storage, keep: 12, delete: 7)
}
