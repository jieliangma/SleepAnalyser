import SwiftUI
import AppKit

struct ScrollWheelZoomModifier: ViewModifier {
    let action: (Double) -> Void
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    if event.modifierFlags.contains(.command) {
                        let delta = Double(event.scrollingDeltaY) * 0.05
                        action(delta)
                        return nil
                    }
                    return event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
            }
    }
}

extension View {
    func onScrollWheelZoom(_ action: @escaping (Double) -> Void) -> some View {
        modifier(ScrollWheelZoomModifier(action: action))
    }
}
