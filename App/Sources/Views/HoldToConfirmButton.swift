import SwiftUI

/// Press-and-hold gate for a destructive action, styled as a filled button.
/// Mirrors Apple's "Clear all" / "Empty Trash" hold pattern: a deliberate hold
/// is much harder to trigger by accident than a single tap on a confirmation dialog.
/// Releasing early cancels with no action and no side effects.
struct HoldToConfirmButton<Label: View>: View {
    let duration: Double
    let tint: Color
    var isDisabled: Bool = false
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var progress: CGFloat = 0
    @State private var isHolding = false
    @State private var holdGeneration = 0

    private let tickCount = 4

    var body: some View {
        label()
            .foregroundStyle(.white)
            .background(
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        tint
                        Color.white.opacity(0.3)
                            .frame(width: geo.size.width * progress)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isHolding ? 0.97 : 1)
            .opacity(isDisabled ? 0.5 : 1)
            .animation(.easeOut(duration: 0.15), value: isHolding)
            .allowsHitTesting(!isDisabled)
            .onLongPressGesture(
                minimumDuration: duration,
                maximumDistance: 50,
                pressing: handlePressing,
                perform: {
                    Haptics.notification(.success)
                    action()
                }
            )
    }

    private func handlePressing(_ pressing: Bool) {
        holdGeneration += 1
        let generation = holdGeneration
        isHolding = pressing
        if pressing {
            withAnimation(.linear(duration: duration)) { progress = 1 }
            scheduleTicks(generation: generation)
        } else {
            withAnimation(.easeOut(duration: 0.15)) { progress = 0 }
        }
    }

    /// Escalating impact ticks during the hold so progress is felt, not just seen;
    /// `generation` guards against ticks firing after an early release or a new press.
    private func scheduleTicks(generation: Int) {
        for i in 1...tickCount {
            let delay = duration * Double(i) / Double(tickCount + 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard generation == holdGeneration, isHolding else { return }
                Haptics.impact(i < tickCount ? .light : .medium)
            }
        }
    }
}
