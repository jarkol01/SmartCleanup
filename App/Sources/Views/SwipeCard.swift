import SwiftUI

/// Shared Tinder-style photo card used by both the training swipe deck and the
/// uncertain-results review deck.
struct SwipeCard: View {
    let image: UIImage
    let dragOffset: CGSize

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(alignment: dragOffset.width > 0 ? .topLeading : .topTrailing) {
                    if abs(dragOffset.width) > 20 {
                        Text(dragOffset.width > 0 ? "ZACHOWAJ" : "USUŃ")
                            .font(.title.weight(.heavy))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(dragOffset.width > 0 ? Color.accent : .destructive, in: Capsule())
                            .foregroundStyle(dragOffset.width > 0 ? Color.onAccent : .onDestructive)
                            .padding(16)
                    }
                }
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width / 20)))
        }
    }
}
