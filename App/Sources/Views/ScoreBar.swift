import SwiftUI

/// A thin rounded bar inset along a thumbnail's bottom edge; width and shade both track a
/// 0...1 score so it reads at a glance without a number competing with the photo. Shared by
/// the ML delete flow's confidence bar and the blur flow's blur-score bar.
struct ScoreBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.45))
                Capsule()
                    .fill(tint)
                    .opacity(0.55 + value * 0.45)
                    .frame(width: geo.size.width * value)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}
