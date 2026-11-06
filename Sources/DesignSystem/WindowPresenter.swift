import AppKit
import SwiftUI

/// Shows SwiftUI content in regular windows from an agent (menu bar) app.
/// One window per identifier; presenting again brings the existing one forward.
final class WindowPresenter: NSObject, NSWindowDelegate {
    static let shared = WindowPresenter()

    private var windows: [String: NSWindow] = [:]

    func window(_ id: String) -> NSWindow? { windows[id] }

    @discardableResult
    func present(id: String,
                 title: String,
                 makeController: () -> NSViewController,
                 transparentTitlebar: Bool = false) -> NSWindow {
        if let existing = windows[id] {
            bringForward(existing)
            return existing
        }

        let controller = makeController()
        let window = NSWindow(contentViewController: controller)
        window.title = title
        window.styleMask = [.titled, .closable]
        if transparentTitlebar {
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        }
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.identifier = NSUserInterfaceItemIdentifier(id)
        window.center()
        windows[id] = window
        bringForward(window)
        return window
    }

    @discardableResult
    func present<Content: View>(id: String, title: String, transparentTitlebar: Bool = false,
                                @ViewBuilder content: () -> Content) -> NSWindow {
        let view = content()
        return present(id: id, title: title, makeController: {
            let host = NSHostingController(rootView: view)
            host.sizingOptions = [.preferredContentSize]
            return host
        }, transparentTitlebar: transparentTitlebar)
    }

    func close(_ id: String) {
        windows[id]?.close()
    }

    private func bringForward(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let id = window.identifier?.rawValue else { return }
        // Release on the next turn of the run loop: dropping the last reference while
        // AppKit is still closing (and animating) the window can crash.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.windows[id] === window, !window.isVisible else { return }
            self.windows[id] = nil
        }
    }
}
