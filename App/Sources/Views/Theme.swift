import Photos
import SwiftUI

// MARK: - Colors

extension ShapeStyle where Self == Color {
    static var appBackground: Color { Color(light: 0xF5F3EE, dark: 0x121412) }
    static var card: Color { Color(light: 0xFFFFFF, dark: 0x1D201D) }
    static var accent: Color { Color(light: 0x2F6F57, dark: 0x7CC4A4) }
    static var onAccent: Color { Color(light: 0xFFFFFF, dark: 0x0E1A14) }
    static var accentSoft: Color { Color(light: 0xE2EEE7, dark: 0x21322A) }
    static var track: Color { Color(light: 0xE8E5DE, dark: 0x2C312C) }
    static var destructive: Color { Color(light: 0xB8442F, dark: 0xE5735C) }
    static var onDestructive: Color { Color(light: 0xFFFFFF, dark: 0x1F0E0A) }
    static var warning: Color { Color(light: 0xF6E7C4, dark: 0x3A3020) }
    static var onWarning: Color { Color(light: 0x5C3D00, dark: 0xF2CF85) }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        func rgb(_ hex: UInt32) -> UIColor {
            UIColor(
                red: CGFloat(hex >> 16 & 0xFF) / 255,
                green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }
        self.init(UIColor { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) })
    }
}

// MARK: - Modifiers

private struct CardModifier: ViewModifier {
    let radius: CGFloat
    let fill: Color
    let padding: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.06), radius: 12, y: 4)
    }
}

extension View {
    func card(radius: CGFloat = 22, fill: Color = .card, padding: CGFloat = 16) -> some View {
        modifier(CardModifier(radius: radius, fill: fill, padding: padding))
    }

    /// Full-screen app background behind a tool screen's content.
    func screenBackground() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.appBackground)
    }

    func chip(_ fill: Color = .accentSoft, _ foreground: Color = .accent) -> some View {
        font(.caption.weight(.heavy))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(fill, in: Capsule())
    }
}

// MARK: - Buttons

/// Capsule button; `.controlSize(.small)` gives the compact, content-sized variant.
struct CapsuleButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        CapsuleLabel(configuration: configuration, fill: fill, foreground: foreground)
    }

    private struct CapsuleLabel: View {
        let configuration: Configuration
        let fill: Color
        let foreground: Color
        @Environment(\.controlSize) private var controlSize
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let small = controlSize == .small || controlSize == .mini
            configuration.label
                .font(small ? .subheadline.weight(.heavy) : .headline.weight(.heavy))
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, small ? 14 : 18)
                .frame(maxWidth: small ? nil : .infinity, minHeight: small ? 36 : 50)
                .background(fill, in: Capsule())
                .contentShape(Capsule())
                .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
        }
    }
}

extension ButtonStyle where Self == CapsuleButtonStyle {
    static var primary: Self { .init(fill: .accent, foreground: .onAccent) }
    static var secondary: Self { .init(fill: .accentSoft, foreground: .accent) }
    static var neutral: Self { .init(fill: .track, foreground: .primary) }
    static var destructive: Self { .init(fill: .destructive, foreground: .onDestructive) }
}

// MARK: - Shared components

struct IconCircle: View {
    let systemImage: String
    var size: CGFloat = 44
    var fill: Color = .accentSoft
    var foreground: Color = .accent

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.footnote.weight(.heavy))
            .kerning(0.6)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

struct InfoRow: View {
    let systemImage: String
    let text: LocalizedStringKey
    var fill: Color = .accentSoft

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.accent)
                .frame(width: 22)
            Text(text)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card(radius: 16, fill: fill, padding: 12)
    }
}

struct ToolRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    var ai = false
    var locked = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                IconCircle(systemImage: systemImage, fill: locked ? .track : .accentSoft, foreground: locked ? .secondary : .accent)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(title).font(.headline.weight(.heavy))
                        if ai { Text(verbatim: "AI").chip() }
                    }
                    Text(locked ? "Najpierw naucz model" : subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: locked ? "lock.fill" : "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(radius: 20, padding: 12)
            .opacity(locked ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }
}

/// Static content of a tool's entry screen; also shown as the results screen's "?" help sheet.
struct ToolIntro {
    let title: LocalizedStringKey
    let systemImage: String
    var ai = false
    let lead: LocalizedStringKey
    var badge: Text?
    /// Markdown text, the bold lead-in written as `**...**`.
    let steps: [(systemImage: String, text: LocalizedStringKey)]
    var infos: [InfoRow] = []
}

struct ToolIntroView<Panel: View>: View {
    let intro: ToolIntro
    @ViewBuilder var panel: Panel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconCircle(systemImage: intro.systemImage, size: 48)
                    Text(intro.title).font(.title.weight(.heavy))
                    if intro.ai { Text(verbatim: "AI").chip() }
                }
                Text(intro.lead)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let badge = intro.badge {
                    badge
                        .font(.footnote.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.card, in: Capsule())
                }

                SectionHeader(title: "Jak to działa").padding(.top, 8)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(intro.steps.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            IconCircle(systemImage: intro.steps[index].systemImage, size: 34)
                            Text(intro.steps[index].text).font(.subheadline)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .card(padding: 14)

                ForEach(intro.infos.indices, id: \.self) { intro.infos[$0] }
            }
            .padding(18)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            if Panel.self != EmptyView.self {
                panel
                    .padding(18)
                    .background(
                        Color.card
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 15, y: -8)
                            .ignoresSafeArea()
                    )
            }
        }
        .screenBackground()
    }
}

extension ToolIntroView where Panel == EmptyView {
    init(intro: ToolIntro) {
        self.init(intro: intro) { EmptyView() }
    }
}

/// Batch size chooser for the delete and blur intros; tapping a size starts right away.
struct BatchPicker: View {
    let title: LocalizedStringKey
    let available: Int
    /// Highlights the smallest size instead of "Wszystkie" and shows `tip`, for a young model.
    var recommendSmall = false
    var tip: LocalizedStringKey?
    let onPick: (Int) -> Void

    private var options: [Int] { [50, 100, 250, 500].filter { $0 < available } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline.weight(.heavy))
                Text("Zostało \(available) nieprzejrzanych zdjęć.")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if recommendSmall, let tip {
                InfoRow(systemImage: "lightbulb", text: tip)
            }
            if !options.isEmpty {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { count in
                        Button { pick(count) } label: { Text(count, format: .number) }
                            .buttonStyle(recommendSmall && count == options.first ? CapsuleButtonStyle.primary : .neutral)
                    }
                }
            }
            Button { pick(available) } label: { Text("Wszystkie (\(available))") }
                .buttonStyle(recommendSmall && !options.isEmpty ? CapsuleButtonStyle.neutral : .primary)
        }
    }

    private func pick(_ count: Int) {
        Haptics.selection()
        onPick(count)
    }
}

/// Shared "done" screen of the delete, blur and duplicate flows.
struct DoneView: View {
    let message: Text
    let freedBytes: Int64
    var infos: [InfoRow] = []
    var onNext: (() -> Void)?
    let onMenu: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                IconCircle(systemImage: "checkmark", size: 88)
                Text("Gotowe").font(.largeTitle.weight(.heavy)).padding(.top, 8)
                message.foregroundStyle(.secondary).multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 2) {
                    Text("zwolniono").font(.subheadline.weight(.bold))
                    Text(verbatim: "~\(formatBytes(freedBytes))")
                        .font(.system(size: 48, weight: .heavy).monospacedDigit())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("Łącznie oszczędzone: ~\(formatBytes(StatsStore.totalBytesFreedEstimate))")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(radius: 26, fill: .accentSoft, padding: 20)
                .padding(.top, 14)

                ForEach(infos.indices, id: \.self) { infos[$0] }
            }
            .padding(18)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let onNext {
                    Button("Przetwórz kolejną partię") {
                        Haptics.selection()
                        onNext()
                    }
                    .buttonStyle(.primary)
                }
                Button("Wróć do menu") {
                    Haptics.selection()
                    onMenu()
                }
                .buttonStyle(onNext == nil ? CapsuleButtonStyle.primary : .init(fill: .clear, foreground: .accent))
            }
            .padding(18)
        }
        .screenBackground()
    }
}

/// Square, rounded photo thumbnail that fills its grid column.
struct AssetThumbnail: View {
    let asset: PHAsset
    var targetSide: CGFloat = 200

    @State private var image: UIImage?

    var body: some View {
        Color.track
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 14, style: .continuous))
            .task(id: asset.localIdentifier) {
                image = await PhotoLibraryService.requestImage(
                    for: asset, targetSize: CGSize(width: targetSide, height: targetSide)
                )
            }
    }
}

/// Amber "?" marker for borderline results.
struct UncertainChip: View {
    var body: some View {
        Text(verbatim: "?")
            .font(.caption.weight(.heavy))
            .foregroundStyle(.onWarning)
            .frame(width: 22, height: 22)
            .background(Color.warning, in: Circle())
    }
}

struct CapsuleBarStyle: ProgressViewStyle {
    var height: CGFloat = 12
    var fill: Color = .accent
    var trackFill: Color = .track

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(trackFill)
                Capsule().fill(fill).frame(width: geo.size.width * (configuration.fractionCompleted ?? 0))
            }
        }
        .frame(height: height)
    }
}

/// Numeric even for 0 ("0 KB", not "Zero KB"), since it follows a "~".
func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.allowsNonnumericFormatting = false
    return formatter.string(fromByteCount: bytes)
}
