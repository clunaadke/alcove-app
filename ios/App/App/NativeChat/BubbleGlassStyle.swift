import SwiftUI

/// The reference values are taken directly from the KKarsyline/liquid-glass
/// setup selected for Alcove. Keep these values in one place so the shader and
/// its sampling allowance cannot drift apart.
struct BubbleGlassStyle {
    var strength: CGFloat
    var dispersion: CGFloat
    var rimWidth: CGFloat
    var magnify: CGFloat
    var backdropBlur: CGFloat

    private static let referenceDiameter: CGFloat = 174.33

    static let reference = BubbleGlassStyle(
        strength: 56.81,
        dispersion: 0.39,
        rimWidth: 0.28,
        magnify: 0,
        backdropBlur: 0.10
    )

    func strength(for lensSize: CGSize) -> CGFloat {
        let diameter = max(1, min(lensSize.width, lensSize.height))
        return strength * diameter / Self.referenceDiameter
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
