import AppKit

@MainActor
final class WindowCloseDelegate: NSObject, NSWindowDelegate {
    weak var workspace: WorkspaceState?
    private var bypassNextClose = false
    private static let windowFrameKey = "smithers.windowFrame"

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let workspace else { return true }
        if workspace.shouldBypassCloseGuards() {
            return true
        }
        if bypassNextClose {
            bypassNextClose = false
            return true
        }
        Task { @MainActor in
            let shouldClose = await workspace.confirmCloseForWindow()
            if shouldClose {
                workspace.persistSessionState()
                bypassNextClose = true
                sender.performClose(nil)
            }
        }
        return false
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        persistWindowFrame(window)
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        persistWindowFrame(window)
    }

    static func loadWindowFrame() -> NSRect? {
        guard let raw = UserDefaults.standard.string(forKey: windowFrameKey) else { return nil }
        let frame = NSRectFromString(raw)
        guard frame.width > 0, frame.height > 0 else { return nil }
        return frame
    }

    private func persistWindowFrame(_ window: NSWindow) {
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Self.windowFrameKey)
    }
}

@MainActor
final class SmithersAppDelegate: NSObject, NSApplicationDelegate {
    weak var workspace: WorkspaceState?
    private var terminationInProgress = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        PressAndHoldDisabler.disable()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let workspace else { return .terminateNow }
        if terminationInProgress {
            return .terminateLater
        }
        terminationInProgress = true
        Task { @MainActor in
            let shouldTerminate = await workspace.confirmCloseForApplication()
            if shouldTerminate {
                workspace.persistSessionState()
                workspace.setCloseGuardsBypassed(true)
            }
            self.terminationInProgress = false
            NSApp.reply(toApplicationShouldTerminate: shouldTerminate)
        }
        return .terminateLater
    }
}
