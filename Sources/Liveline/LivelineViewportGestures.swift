import CoreGraphics
import SwiftUI

/// Platform plumbing for the two zoom-and-pan inputs that SwiftUI does not
/// express uniformly: the magnify gesture, whose modern spelling carries the
/// centroid the zoom has to pivot on, and the macOS scroll wheel, which has no
/// gesture at all.
///
/// Both no-op where the platform cannot provide them, so the call site in
/// ``LivelineChart`` stays free of `#if` blocks.
extension View {
    /// Attaches a pinch that reports its cumulative magnification and the point
    /// it started from.
    ///
    /// `MagnifyGesture` is the only spelling that carries a start location, and
    /// it needs iOS 17 / macOS 14. Earlier systems get pan, scroll, and the
    /// "Live" control, but no pinch — an anchorless zoom that jumps the plot
    /// out from under the fingers is worse than none.
    @ViewBuilder
    func magnifiableViewport(
        onChanged: @escaping (CGFloat, CGPoint) -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        #if os(tvOS) || os(watchOS)
        self
        #else
        if #available(iOS 17.0, macOS 14.0, visionOS 1.0, *) {
            simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        onChanged(value.magnification, value.startLocation)
                    }
                    .onEnded { _ in onEnded() }
            )
        } else {
            self
        }
        #endif
    }

    /// Routes trackpad and wheel scrolling over the plot into a horizontal pan.
    /// Only macOS has such events; everywhere else this is the identity.
    @ViewBuilder
    func scrollWheelPan(
        isEnabled: Bool,
        onPan: @escaping (CGFloat) -> Void
    ) -> some View {
        #if os(macOS)
        overlay {
            LivelineScrollPanView(isEnabled: isEnabled, onPan: onPan)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
        #else
        self
        #endif
    }
}
