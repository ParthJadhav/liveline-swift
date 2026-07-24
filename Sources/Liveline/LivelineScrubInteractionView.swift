#if os(iOS)
import SwiftUI
import UIKit

/// An iOS interaction surface that resolves chart scrubbing against an
/// ancestor scroll view before either gesture begins mutating chart state.
struct LivelineScrubInteractionView: UIViewRepresentable {
    var isEnabled: Bool
    var onScrub: (CGPoint) -> Void
    var onEnd: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrub: onScrub, onEnd: onEnd)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isAccessibilityElement = false

        let recognizer = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        recognizer.minimumNumberOfTouches = 1
        recognizer.maximumNumberOfTouches = 1
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        context.coordinator.attach(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(
            isEnabled: isEnabled,
            onScrub: onScrub,
            onEnd: onEnd
        )
        uiView.isUserInteractionEnabled = isEnabled
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.cancelActiveScrub()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var recognizer: UIPanGestureRecognizer?
        private var session = LivelineScrubSession()
        private var isEnabled = true
        private var onScrub: (CGPoint) -> Void
        private var onEnd: () -> Void

        init(
            onScrub: @escaping (CGPoint) -> Void,
            onEnd: @escaping () -> Void
        ) {
            self.onScrub = onScrub
            self.onEnd = onEnd
        }

        func attach(_ recognizer: UIPanGestureRecognizer) {
            self.recognizer = recognizer
        }

        func update(
            isEnabled: Bool,
            onScrub: @escaping (CGPoint) -> Void,
            onEnd: @escaping () -> Void
        ) {
            self.onScrub = onScrub
            self.onEnd = onEnd
            self.isEnabled = isEnabled

            if recognizer?.isEnabled != isEnabled {
                if !isEnabled {
                    cancelActiveScrub()
                }
                recognizer?.isEnabled = isEnabled
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }

            switch recognizer.state {
            case .began:
                guard session.begin() else { return }
                onScrub(recognizer.location(in: view))

            case .changed:
                guard session.shouldUpdate else { return }
                onScrub(recognizer.location(in: view))

            case .ended, .cancelled, .failed:
                finishActiveScrub()

            case .possible:
                break

            @unknown default:
                finishActiveScrub()
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled,
                  let recognizer = gestureRecognizer as? UIPanGestureRecognizer,
                  recognizer === self.recognizer else {
                return false
            }

            return LivelineScrubPanPolicy.shouldBegin(
                velocity: recognizer.velocity(in: recognizer.view)
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard let recognizer,
                  gestureRecognizer === recognizer || otherGestureRecognizer === recognizer else {
                return false
            }

            let other = gestureRecognizer === recognizer
                ? otherGestureRecognizer
                : gestureRecognizer
            return isAncestorScrollViewPan(other, of: recognizer.view)
        }

        func cancelActiveScrub() {
            finishActiveScrub()
        }

        private func finishActiveScrub() {
            guard session.finish() else { return }
            onEnd()
        }

        private func isAncestorScrollViewPan(
            _ candidate: UIGestureRecognizer,
            of view: UIView?
        ) -> Bool {
            var ancestor = view?.superview
            while let current = ancestor {
                if let scrollView = current as? UIScrollView,
                   candidate === scrollView.panGestureRecognizer {
                    return true
                }
                ancestor = current.superview
            }
            return false
        }
    }
}
#endif
