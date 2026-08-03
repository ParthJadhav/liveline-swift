import SwiftUI

/// Cursor-driven inspection for platforms that report a free-moving pointer.
///
/// macOS always has one, iPadOS has one whenever a trackpad, mouse, or Apple
/// Pencil hover is attached, and visionOS reports gaze/pinch pointer movement.
/// tvOS and watchOS have no cursor at all, so the modifier compiles away to the
/// unmodified view there instead of forcing every call site to branch.
///
/// `onContinuousHover` itself only arrived in iOS 16 / macOS 13, one release
/// above the package floor, so the modifier also compiles away on the two
/// oldest supported releases. Hover inspection is an enhancement over scrubbing
/// rather than the only way to inspect a chart, so losing it there costs no
/// functionality that a touch or a trackpad drag cannot reach.
extension View {
    @ViewBuilder
    func livelinePointerHover(
        isEnabled: Bool,
        onMove: @escaping (CGPoint) -> Void,
        onExit: @escaping () -> Void
    ) -> some View {
        #if os(macOS) || os(iOS) || os(visionOS)
        if #available(iOS 16.0, macOS 13.0, visionOS 1.0, *) {
            onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case let .active(location):
                    guard isEnabled else { return }
                    onMove(location)
                case .ended:
                    // Always report the exit, even once the feature has been
                    // turned off mid-hover, so a lingering selection cannot
                    // outlive the pointer that produced it.
                    onExit()
                @unknown default:
                    onExit()
                }
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
}
