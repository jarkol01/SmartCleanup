import SwiftUI

// Shared with the widget extension.

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

// MARK: - Shared components

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
