import SwiftUI

@MainActor
final class VerticalDragAutoScroller: ObservableObject {
    private weak var scrollView: UIScrollView?
    private var displayLink: CADisplayLink?
    private var velocity: CGFloat = 0
    private var previousTimestamp: CFTimeInterval?

    func attach(toAncestorOf view: UIView) {
        var ancestor = view.superview
        while let current = ancestor {
            if let scrollView = current as? UIScrollView {
                self.scrollView = scrollView
                return
            }
            ancestor = current.superview
        }
    }

    func update(fingerY: CGFloat, viewportHeight: CGFloat) {
        guard viewportHeight > 0 else {
            stop()
            return
        }
        let edgeSize = min(96, viewportHeight * 0.22)
        let maximumSpeed: CGFloat = 520
        if fingerY < edgeSize {
            let intensity = min(1, max(0, (edgeSize - fingerY) / edgeSize))
            setVelocity(-maximumSpeed * intensity * intensity)
        } else if fingerY > viewportHeight - edgeSize {
            let intensity = min(1, max(0, (fingerY - viewportHeight + edgeSize) / edgeSize))
            setVelocity(maximumSpeed * intensity * intensity)
        } else {
            stop()
        }
    }

    func stop() {
        velocity = 0
        previousTimestamp = nil
        displayLink?.invalidate()
        displayLink = nil
    }

    private func setVelocity(_ velocity: CGFloat) {
        self.velocity = velocity
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let scrollView else {
            stop()
            return
        }
        let elapsed = previousTimestamp.map { min(link.timestamp - $0, 1.0 / 30.0) } ?? 0
        previousTimestamp = link.timestamp
        guard elapsed > 0 else { return }

        let minimumY = -scrollView.adjustedContentInset.top
        let maximumY = max(
            minimumY,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        let proposedY = scrollView.contentOffset.y + velocity * elapsed
        let clampedY = min(maximumY, max(minimumY, proposedY))
        guard abs(clampedY - scrollView.contentOffset.y) > 0.1 else {
            stop()
            return
        }
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: clampedY), animated: false)
    }
}

struct VerticalDragScrollViewResolver: UIViewRepresentable {
    let autoScroller: VerticalDragAutoScroller

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        resolve(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        resolve(from: uiView)
    }

    private func resolve(from view: UIView) {
        DispatchQueue.main.async { [weak view] in
            guard let view else { return }
            autoScroller.attach(toAncestorOf: view)
        }
    }
}
