import SwiftUI

/// User-tunable values for Alcove's rounded-rectangle liquid-glass lens.
/// Defaults match the values shown in KKarsyline/liquid-glass's reference panel.
struct BubbleGlassStyle {
    var strength: CGFloat
    var dispersion: CGFloat
    var rimWidth: CGFloat
    var magnify: CGFloat
    var backdropBlur: CGFloat
    var size: CGFloat

    static let reference = BubbleGlassStyle(
        strength: 56.81,
        dispersion: 0.39,
        rimWidth: 0.28,
        magnify: 0,
        backdropBlur: 0.10,
        size: 174.33
    )

    func strength(for lensSize: CGSize) -> CGFloat {
        let diameter = max(1, min(lensSize.width, lensSize.height))
        return strength * diameter / max(1, size)
    }

    func maximumSampleOffset(for lensSize: CGSize) -> CGSize {
        let effectiveStrength = strength(for: lensSize)
        let minDimension = max(1, min(lensSize.width, lensSize.height))
        let reach = ceil(
            effectiveStrength * (1 + dispersion)
            + magnify * minDimension * 0.42
            + backdropBlur * 2
            + 2
        )
        return CGSize(width: reach, height: reach)
    }
}

private struct BubbleGlassStyleKey: EnvironmentKey {
    static let defaultValue = BubbleGlassStyle.reference
}

extension EnvironmentValues {
    var bubbleGlassStyle: BubbleGlassStyle {
        get { self[BubbleGlassStyleKey.self] }
        set { self[BubbleGlassStyleKey.self] = newValue }
    }
}
