import AppKit

struct WatchableApp: Hashable {
    let bundleIdentifier: String
    let name: String
    let processIdentifier: pid_t

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: WatchableApp, rhs: WatchableApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

protocol AppWatchdogDelegate: AnyObject {
    func watchdogDidDetectAppTermination(_ watchdog: AppWatchdog, app: WatchableApp)
}

class AppWatchdog {
    weak var delegate: AppWatchdogDelegate?
    private(set) var watchedApp: WatchableApp?

    private var pollingTimer: Timer?
    private var terminationObserver: NSObjectProtocol?

    var isWatching: Bool { watchedApp != nil }

    func startWatching(_ app: WatchableApp) {
        stopWatching()
        watchedApp = app

        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let terminatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  terminatedApp.bundleIdentifier == self.watchedApp?.bundleIdentifier else {
                return
            }
            self.handleAppTerminated()
        }

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkAppStillRunning()
        }
    }

    func stopWatching() {
        watchedApp = nil
        if let observer = terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            terminationObserver = nil
        }
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func toggleWatching(_ app: WatchableApp) -> Bool {
        if watchedApp?.bundleIdentifier == app.bundleIdentifier {
            stopWatching()
            return false
        } else {
            startWatching(app)
            return true
        }
    }

    // MARK: - Private

    private func handleAppTerminated() {
        guard watchedApp != nil else { return }
        let app = watchedApp!
        stopWatching()
        delegate?.watchdogDidDetectAppTermination(self, app: app)
    }

    private func checkAppStillRunning() {
        guard let watched = watchedApp else { return }
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == watched.bundleIdentifier
        }
        if running.isEmpty {
            handleAppTerminated()
        }
    }

    // MARK: - App Discovery

    static func runningUserApps(excludingBundleID: String?) -> [WatchableApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != excludingBundleID }
            .compactMap { app in
                guard let name = app.localizedName,
                      let bundleID = app.bundleIdentifier else { return nil }
                return WatchableApp(
                    bundleIdentifier: bundleID,
                    name: name,
                    processIdentifier: app.processIdentifier
                )
            }
            .reduce(into: [String: WatchableApp]()) { dict, app in
                dict[app.bundleIdentifier] = app
            }
            .values
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
