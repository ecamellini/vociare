import AppKit
import SwiftUI

@MainActor
final class OverlayModel: ObservableObject {
    static let barCount = 24
    @Published var levels = Array(repeating: Float(0), count: barCount)
    @Published var isTranscribing = false
}

/// A floating pill at the bottom of the screen that never takes focus, so the paste lands in the app being dictated into.
@MainActor
final class Overlay {
    private let model = OverlayModel()
    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: OverlayView(model: model))
        return panel
    }()

    func show() {
        model.levels = Array(repeating: 0, count: OverlayModel.barCount)
        model.isTranscribing = false
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.minY + 60))
        }
        panel.orderFrontRegardless()
    }

    func push(level: Float) {
        model.levels = Array(model.levels.dropFirst()) + [level]
    }

    func showTranscribing() {
        model.isTranscribing = true
    }

    func hide() {
        panel.orderOut(nil)
    }
}

private struct OverlayView: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        ZStack {
            Capsule().fill(.black.opacity(0.85))
            Capsule().strokeBorder(.white.opacity(0.15))
            if model.isTranscribing {
                ProgressView().controlSize(.small).tint(.white)
            } else {
                HStack(spacing: 3) {
                    ForEach(model.levels.indices, id: \.self) { index in
                        Capsule()
                            .fill(.white)
                            .frame(width: 3, height: 3 + CGFloat(model.levels[index]) * 22)
                    }
                }
                .animation(.linear(duration: 0.08), value: model.levels)
            }
        }
        .frame(width: 160, height: 44)
    }
}
