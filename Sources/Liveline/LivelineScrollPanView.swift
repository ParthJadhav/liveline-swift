#if os(macOS)
import AppKit
import SwiftUI

/// Turns trackpad and wheel scrolling over the plot into a horizontal pan.
///
/// SwiftUI exposes no scroll-wheel gesture, and an AppKit overlay that answered
/// hit tests would take the mouse events that hover and clicking depend on. So
/// this view opts out of hit testing entirely and exists only to give a local
/// event monitor a rectangle to test the cursor against. Events outside that
/// rectangle, and events the policy does not claim, are passed through
/// untouched — a chart inside a scroll view still scrolls.
struct LivelineScrollPanView: NSViewRepresentable {
    var isEnabled: Bool
    var onPan: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isEnabled: isEnabled, onPan: onPan)
    }

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(isEnabled: isEnabled, onPan: onPan)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    /// Invisible to the mouse: every hit test falls through to the chart below.
    final class PassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    @MainActor
    final class Coordinator {
        private weak var view: NSView?
        private var monitor: MonitorToken?
        private var isEnabled: Bool
        private var onPan: (CGFloat) -> Void

        init(isEnabled: Bool, onPan: @escaping (CGFloat) -> Void) {
            self.isEnabled = isEnabled
            self.onPan = onPan
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor.value)
            }
        }

        func attach(to view: NSView) {
            self.view = view
            guard monitor == nil else { return }
            if let token = NSEvent.addLocalMonitorForEvents(
                matching: .scrollWheel,
                handler: { [weak self] event in self?.handle(event) ?? event }
            ) {
                monitor = MonitorToken(token)
            }
        }

        func update(isEnabled: Bool, onPan: @escaping (CGFloat) -> Void) {
            self.isEnabled = isEnabled
            self.onPan = onPan
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor.value)
            }
            monitor = nil
            view = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard isEnabled,
                  let view,
                  let window = view.window,
                  event.window === window
            else {
                return event
            }

            let local = view.convert(event.locationInWindow, from: nil)
            guard view.bounds.contains(local) else { return event }

            let delta = LivelineScrollPanPolicy.horizontalDelta(
                deltaX: event.scrollingDeltaX,
                deltaY: event.scrollingDeltaY,
                isShiftPressed: event.modifierFlags.contains(.shift)
            )
            guard delta != 0 else { return event }
            onPan(delta)
            return nil
        }

        /// AppKit returns an opaque, non-Sendable event-monitor token. The
        /// token is never inspected and NSEvent owns its synchronization; this
        /// wrapper only permits deterministic cleanup from `deinit`.
        private final class MonitorToken: @unchecked Sendable {
            let value: Any

            init(_ value: Any) {
                self.value = value
            }
        }
    }
}
#endif
