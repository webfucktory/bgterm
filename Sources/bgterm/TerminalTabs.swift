import AppKit
import BgtermCore

/// Manages a set of terminal tabs with no visible tab bar. Tabs are created,
/// closed, and switched entirely via keyboard (handled by AppCoordinator). Only
/// the active tab's surface is shown; the rest are hidden but keep running.
final class TerminalTabs {
    let root: NSView
    private var surfaces: [TerminalSurface] = []
    private(set) var activeIndex = 0
    private let settingsProvider: () -> Settings

    init(frame: NSRect, settings: @escaping () -> Settings) {
        settingsProvider = settings
        root = NSView(frame: frame)
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.black.cgColor
        root.autoresizesSubviews = true
        newTab()
    }

    var activeView: NSView? { surfaces.indices.contains(activeIndex) ? surfaces[activeIndex].view : nil }
    var count: Int { surfaces.count }

    func newTab() {
        let surface = TerminalSurface(frame: root.bounds)
        surface.apply(settingsProvider())
        surface.container.frame = root.bounds
        surface.container.autoresizingMask = [.width, .height]
        root.addSubview(surface.container)
        surface.start()
        surfaces.append(surface)
        activeIndex = surfaces.count - 1
        showActive()
    }

    func closeActive() {
        guard surfaces.indices.contains(activeIndex) else { return }
        let surface = surfaces.remove(at: activeIndex)
        surface.terminate()
        surface.container.removeFromSuperview()
        if surfaces.isEmpty {
            newTab()   // always keep at least one tab alive
            return
        }
        activeIndex = min(activeIndex, surfaces.count - 1)
        showActive()
    }

    func select(_ index: Int) {
        guard surfaces.indices.contains(index) else { return }
        activeIndex = index
        showActive()
    }

    func applyAll(_ settings: Settings) {
        surfaces.forEach { $0.apply(settings) }
    }

    func restartActive() {
        guard surfaces.indices.contains(activeIndex) else { return }
        surfaces[activeIndex].restart()
    }

    private func showActive() {
        for (i, surface) in surfaces.enumerated() {
            surface.container.isHidden = (i != activeIndex)
        }
    }
}
