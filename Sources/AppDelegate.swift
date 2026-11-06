import AppKit
import os.log

private let logger = Logger(subsystem: "com.m3etis.clamkeep", category: "app")

struct WakeReason: OptionSet {
    let rawValue: Int
    static let manual    = WakeReason(rawValue: 1 << 0)
    static let downloads = WakeReason(rawValue: 1 << 1)
    static let app       = WakeReason(rawValue: 1 << 2)
}

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var allowDisplaySleepMenuItem: NSMenuItem!
    var allowAutoLockMenuItem: NSMenuItem!
    var downloadMonitorMenuItem: NSMenuItem!
    var stayAwakeMenuItem: NSMenuItem!
    var stayAwakeSubmenu: NSMenu!
    var timerSubmenuItem: NSMenuItem!
    var timerSubmenu: NSMenu!
    var showSystemMetrics = true
    var headerMenuItem: NSMenuItem!
    var statusHeader: StatusHeaderView!
    var wakeShortcutItem: NSMenuItem!
    let model = AppModel()
    lazy var settingsWindow = SettingsWindowController(model: model)
    let showSystemMetricsKey = "ClamKeepShowSystemMetrics"

    var isActive = false
    var wakeStartTime: Date?
    var displayTimer: Timer?
    var caffeinateProcess: Process?
    var allowDisplaySleep = false
    let allowDisplaySleepKey = "ClamKeepAllowDisplaySleep"
    /// Display hold is the default Wake Mode behavior; Display Sleep [ON] turns it off.
    var shouldHoldDisplay: Bool { !allowDisplaySleep }
    var downloadMonitorEnabled = false
    let downloadMonitorKey = "ClamKeepDownloadMonitor"
    var downloadMonitorTimer: Timer?

    var autoOffMinutes: Int? {
        didSet {
            if let minutes = autoOffMinutes {
                UserDefaults.standard.set(minutes, forKey: autoOffMinutesKey)
                let deadline = autoOffDeadline ?? Date().addingTimeInterval(TimeInterval(minutes) * 60)
                autoOffDeadline = deadline
                UserDefaults.standard.set(deadline, forKey: autoOffDeadlineKey)
            } else {
                UserDefaults.standard.removeObject(forKey: autoOffMinutesKey)
                UserDefaults.standard.removeObject(forKey: autoOffDeadlineKey)
                autoOffDeadline = nil
            }
        }
    }
    var autoOffDeadline: Date?
    let autoOffMinutesKey = "ClamKeepAutoOffMinutes"
    let autoOffDeadlineKey = "ClamKeepAutoOffDeadline"
    static let timerPresets = [15, 30, 45, 60, 120, 240]

    var allowAutoLock = false
    let allowAutoLockKey = "ClamKeepAllowAutoLock"
    /// Auto-lock hold is the default Wake Mode behavior; Auto Lock [ON] turns it off.
    var shouldHoldAutoLock: Bool { !allowAutoLock }
    let autoLockOverrideActiveKey = "ClamKeepAutoLockOverrideActive"
    let autoLockSavedDelayKey = "ClamKeepAutoLockSavedDelay"
    let autoLockSavedHadKeyKey = "ClamKeepAutoLockSavedHadKey"
    let autoLockOverrideDelay = 315_360_000.0


    var downloadMonitorSince: Date?
    var watchedAppSince: Date?

    var wakeReasons: WakeReason = []
    var displayOverrideHeld = false
    let displayOverrideHeldKey = "ClamKeepDisplayOverrideHeld"
    var isEnablingWake = false
    /// Bumped on every enable/disable so a stale async enable cannot resurrect a cancelled session.
    var wakeGeneration = 0
    /// Serializes enable/disable IPC so a cancelled enable cannot land after disable.
    let lifecycleLock = NSLock()

    var watchdog = AppWatchdog()

    let wakeStartKey = "ClamKeepWakeStartTime"

    var screensaverDefaults: UserDefaults? {
        UserDefaults(suiteName: "com.apple.screensaver")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        watchdog.delegate = self
        // Before migrateAllowFlags(): it writes keys used to detect an upgrade.
        MenuBarIcon.migrateDefaults()
        // Must precede setupMenu() so the metrics header respects the saved toggle.
        showSystemMetrics = UserDefaults.standard.object(forKey: showSystemMetricsKey) as? Bool ?? true
        setupStatusItem()
        setupMenu()
        MainMenu.install(target: self, settings: #selector(openSettings), quit: #selector(quitApp))
        migrateAllowFlags()
        configureModel()
        // Non-blocking: the onboarding window appears only if the helper is missing or outdated.
        refreshHelperState(presentSetupIfNeeded: true)

        checkInitialState()
        if showSystemMetrics {
            SystemMetrics.warmUp()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        performWakeTeardownSync()
    }

    // MARK: - State

    /// One-time invert of 1.6 Prevent* prefs into Allow* exceptions.
    /// Fresh installs default to both Allow OFF (= hold display + hold auto lock).
    func migrateAllowFlags() {
        let d = UserDefaults.standard
        let oldDisplay = "ClamKeepPreventDisplaySleep"
        let oldLock = "ClamKeepPreventAutoLock"

        if d.object(forKey: allowDisplaySleepKey) == nil {
            if let old = d.object(forKey: oldDisplay) as? Bool {
                d.set(!old, forKey: allowDisplaySleepKey)
            } else {
                d.set(false, forKey: allowDisplaySleepKey)
            }
        }
        d.removeObject(forKey: oldDisplay)

        if d.object(forKey: allowAutoLockKey) == nil {
            if let old = d.object(forKey: oldLock) as? Bool {
                d.set(!old, forKey: allowAutoLockKey)
            } else {
                d.set(false, forKey: allowAutoLockKey)
            }
        }
        d.removeObject(forKey: oldLock)
    }

    func checkInitialState() {
        allowDisplaySleep = UserDefaults.standard.bool(forKey: allowDisplaySleepKey)
        downloadMonitorEnabled = UserDefaults.standard.bool(forKey: downloadMonitorKey)
        allowAutoLock = UserDefaults.standard.bool(forKey: allowAutoLockKey)
        displayOverrideHeld = UserDefaults.standard.bool(forKey: displayOverrideHeldKey)
        if UserDefaults.standard.object(forKey: autoOffMinutesKey) != nil {
            // Read the stored deadline BEFORE assigning autoOffMinutes — its didSet
            // overwrites the defaults entry with a fresh now+minutes deadline.
            let storedDeadline = UserDefaults.standard.object(forKey: autoOffDeadlineKey) as? Date
            autoOffMinutes = UserDefaults.standard.integer(forKey: autoOffMinutesKey)
            if let stored = storedDeadline {
                if stored > Date() {
                    autoOffDeadline = stored
                    UserDefaults.standard.set(stored, forKey: autoOffDeadlineKey)
                } else {
                    autoOffDeadline = nil
                    autoOffMinutes = nil
                }
            }
        }

        // Stale autolock override from a previous crash — restore unless we will keep holding it.
        if UserDefaults.standard.bool(forKey: autoLockOverrideActiveKey), allowAutoLock {
            restoreAutoLockOverride()
        }

        // Restore watchdog target if persisted
        if let bundleID = UserDefaults.standard.string(forKey: "ClamKeepWatchdogBundleID"),
           let name = UserDefaults.standard.string(forKey: "ClamKeepWatchdogAppName") {
            let pid = NSWorkspace.shared.runningApplications
                .first { $0.bundleIdentifier == bundleID }?.processIdentifier ?? 0
            if pid != 0 {
                let app = WatchableApp(bundleIdentifier: bundleID, name: name, processIdentifier: pid)
                watchdog.startWatching(app)
                watchedAppSince = Date()
            }
        }

        if downloadMonitorEnabled {
            downloadMonitorSince = Date()
            startDownloadMonitor()
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let sleepDisabled = PrivilegedShell.isSleepDisabled()
            DispatchQueue.main.async {
                guard let self = self else { return }
                if sleepDisabled {
                    self.wakeReasons = [.manual]
                    if self.watchdog.isWatching {
                        self.wakeReasons.insert(.app)
                    }
                    self.isActive = true
                    self.wakeStartTime = UserDefaults.standard.object(forKey: self.wakeStartKey) as? Date ?? Date()
                    self.syncDisplayHold()
                    self.startCaffeinate(holdDisplay: self.shouldHoldDisplay)
                    self.updateUI(active: true)
                    self.startDisplayTimer()
                } else {
                    // No wake session — an auto-off timer cannot run without it.
                    self.autoOffMinutes = nil
                    if self.watchdog.isWatching {
                        self.addWakeReason(.app)
                    }
                }
                if self.downloadMonitorEnabled { self.downloadMonitorSince = self.downloadMonitorSince ?? Date() }
                self.syncAutoLock()
            }
        }
    }

    func formattedDuration(since: Date?, long: Bool) -> String {
        guard let since else { return long ? "00:00:00" : "0s" }
        let elapsed = max(0, Int(Date().timeIntervalSince(since)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60

        if long {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }

        switch L.current {
        case .english:
            if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
            if minutes > 0 { return String(format: "%dm %02ds", minutes, seconds) }
            return "\(seconds)s"
        case .russian:
            if hours > 0 { return String(format: "%dч %02dм", hours, minutes) }
            if minutes > 0 { return String(format: "%dм %02dс", minutes, seconds) }
            return "\(seconds)с"
        case .kazakh:
            if hours > 0 { return String(format: "%dс %02dм", hours, minutes) }
            if minutes > 0 { return String(format: "%dм %02dс", minutes, seconds) }
            return "\(seconds)с"
        }
    }

    // MARK: - Auto-off Timer

    @objc func setAutoOffOff() {
        autoOffDeadline = nil
        autoOffMinutes = nil
        rebuildMenu()
    }

    @objc func setAutoOffPreset(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        autoOffDeadline = nil
        autoOffMinutes = minutes
        if !isActive {
            addWakeReason(.manual)
        }
        rebuildMenu()
    }

    func checkAutoOff() {
        guard let deadline = autoOffDeadline, Date() >= deadline else { return }
        clearAllWakeReasons()
        rebuildMenu()
    }

    // MARK: - Wake Reasons

    func addWakeReason(_ reason: WakeReason) {
        wakeReasons.insert(reason)
        if !isActive && !isEnablingWake {
            enableWakeMode()
        }
    }

    func removeWakeReason(_ reason: WakeReason) {
        guard wakeReasons.contains(reason) else { return }
        wakeReasons.remove(reason)
        if wakeReasons.isEmpty && (isActive || isEnablingWake) {
            disableWakeMode()
        }
    }

    func clearAllWakeReasons() {
        // Manual off / auto-off expiry ends the whole keep-awake session.
        autoOffMinutes = nil
        wakeReasons = []
        watchdog.stopWatching()
        watchedAppSince = nil
        // Stop download policy so it cannot re-enable wake within seconds.
        stopDownloadMonitor()
        downloadMonitorEnabled = false
        downloadMonitorSince = nil
        UserDefaults.standard.set(false, forKey: downloadMonitorKey)
        // Cancel exception toggles so no other option stays lit after Wake Mode off.
        setAllowDisplaySleep(false)
        setAllowAutoLock(false)
        disableWakeMode()
    }

    func setAllowDisplaySleep(_ value: Bool) {
        allowDisplaySleep = value
        UserDefaults.standard.set(value, forKey: allowDisplaySleepKey)
    }

    func setAllowAutoLock(_ value: Bool) {
        allowAutoLock = value
        UserDefaults.standard.set(value, forKey: allowAutoLockKey)
    }

    // MARK: - Actions

    @objc func toggleWake() {
        // While enable IPC is in flight a second click must not cancel the
        // session — the user is trying to turn Wake Mode on, not off.
        if isEnablingWake { return }

        if isActive {
            clearAllWakeReasons()
            return
        }

        addWakeReason(.manual)
    }

    func enableWakeMode() {
        if isActive || isEnablingWake { return }

        // Fresh session: Display Sleep and Auto Lock are forbidden until the
        // user re-enables them manually as exceptions.
        setAllowDisplaySleep(false)
        setAllowAutoLock(false)

        isEnablingWake = true

        // Optimistic ON so the toggle responds before helper IPC returns.
        isActive = true
        wakeStartTime = Date()
        UserDefaults.standard.set(wakeStartTime, forKey: wakeStartKey)
        startCaffeinate(holdDisplay: shouldHoldDisplay)
        updateUI(active: true)
        startDisplayTimer()
        syncAutoLock()

        lifecycleLock.lock()
        wakeGeneration += 1
        let generation = wakeGeneration
        lifecycleLock.unlock()

        let holdDisplay = shouldHoldDisplay
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var sleepOk = false
            for attempt in 1...3 {
                sleepOk = PrivilegedShell.sendCommand("enable")
                if sleepOk { break }
                logger.error("enable command failed (attempt \(attempt))")
                Thread.sleep(forTimeInterval: 0.3)
            }

            var displayOk = true
            if holdDisplay {
                displayOk = PrivilegedShell.sendCommand("display_enable")
                if !displayOk {
                    logger.error("display_enable failed, sleep prevention still active")
                }
            }

            DispatchQueue.main.async {
                self.finishEnable(generation: generation, sleepOk: sleepOk, displayOk: displayOk, holdDisplay: holdDisplay)
            }
        }
    }

    func finishEnable(generation: Int, sleepOk: Bool, displayOk: Bool, holdDisplay: Bool) {
        lifecycleLock.lock()
        let isCurrent = generation == wakeGeneration
        lifecycleLock.unlock()

        if isCurrent {
            isEnablingWake = false
        }
        guard isCurrent else { return }

        if sleepOk {
            setDisplayOverrideHeld(holdDisplay && displayOk)
            startCaffeinate(holdDisplay: shouldHoldDisplay)
            updateUI(active: true)
            startDisplayTimer()
            syncAutoLock()
        } else {
            // Helper rejected enable after retries — roll back so the next click can try again.
            isActive = false
            wakeReasons = []
            wakeStartTime = nil
            UserDefaults.standard.removeObject(forKey: wakeStartKey)
            stopCaffeinate()
            updateUI(active: false)
            stopDisplayTimer()
            syncAutoLock()
        }
    }

    func disableWakeMode() {
        lifecycleLock.lock()
        // Bump generation so a stale async enable cannot resurrect this session.
        wakeGeneration += 1
        let generation = wakeGeneration
        lifecycleLock.unlock()
        isEnablingWake = false
        stopCaffeinate()

        // Local teardown is authoritative for UI — helper IPC can time out even
        // after a successful disable, and a failed IPC must not leave the toggle ON.
        isActive = false
        wakeStartTime = nil
        UserDefaults.standard.removeObject(forKey: wakeStartKey)
        autoOffMinutes = nil
        updateUI(active: false)
        stopDisplayTimer()
        syncAutoLock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            self.lifecycleLock.lock()
            let isCurrent = generation == self.wakeGeneration
            self.lifecycleLock.unlock()
            // A newer enable has started — do not disable under it.
            guard isCurrent else { return }

            let sleepOk = PrivilegedShell.sendCommand("disable")
            if !sleepOk {
                logger.error("disable command failed")
            }

            self.lifecycleLock.lock()
            let stillCurrent = generation == self.wakeGeneration
            self.lifecycleLock.unlock()
            if stillCurrent && self.displayOverrideHeld {
                PrivilegedShell.sendCommand("display_disable")
                DispatchQueue.main.async {
                    self.setDisplayOverrideHeld(false)
                }
            }
        }
    }

    func performWakeTeardownSync() {
        stopDownloadMonitor()
        stopCaffeinate()
        watchdog.stopWatching()
        watchedAppSince = nil

        if !wakeReasons.isEmpty || isActive || PrivilegedShell.isSleepDisabled() {
            PrivilegedShell.sendCommand("disable")
            if displayOverrideHeld {
                PrivilegedShell.sendCommand("display_disable")
            }
        }
        restoreAutoLockOverride()

        wakeReasons = []
        isActive = false
        autoOffMinutes = nil
        setDisplayOverrideHeld(false)
    }

    // MARK: - Caffeinate

    func startCaffeinate(holdDisplay: Bool) {
        stopCaffeinate()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        // -i: system idle-awake (always with Wake Mode); -d: also hold the display.
        process.arguments = holdDisplay ? ["-d", "-i"] : ["-i"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] _ in
            guard let self = self, self.isActive else { return }
            logger.warning("caffeinate exited unexpectedly, restarting")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.isActive {
                    self.startCaffeinate(holdDisplay: self.shouldHoldDisplay)
                }
            }
        }
        do {
            try process.run()
            caffeinateProcess = process
        } catch {
            logger.error("Failed to start caffeinate: \(error.localizedDescription)")
        }
    }

    func stopCaffeinate() {
        if let process = caffeinateProcess, process.isRunning {
            process.terminationHandler = nil
            process.terminate()
        }
        caffeinateProcess = nil
    }

    // MARK: - Timer

    func startDisplayTimer() {
        stopDisplayTimer()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimerDisplay()
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    func updateTimerDisplay() {
        checkAutoOff()
        refreshLiveTimers()
    }

    // MARK: - Display Sleep

    /// Keeps `pmset displaysleep` in sync with the Allow flag while Wake Mode is held.
    func syncDisplayHold() {
        let holdDisplay = shouldHoldDisplay
        if holdDisplay && !displayOverrideHeld {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let ok = PrivilegedShell.sendCommand("display_enable")
                DispatchQueue.main.async {
                    self?.setDisplayOverrideHeld(ok)
                }
            }
        } else if !holdDisplay && displayOverrideHeld {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                PrivilegedShell.sendCommand("display_disable")
                DispatchQueue.main.async {
                    self?.setDisplayOverrideHeld(false)
                }
            }
        }
    }

    func setDisplayOverrideHeld(_ held: Bool) {
        displayOverrideHeld = held
        UserDefaults.standard.set(held, forKey: displayOverrideHeldKey)
    }

    @objc func toggleAllowDisplaySleep() {
        setAllowDisplaySleep(!allowDisplaySleep)

        if isActive {
            stopCaffeinate()
            let holdDisplay = shouldHoldDisplay
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                if holdDisplay {
                    let ok = PrivilegedShell.sendCommand("display_enable")
                    DispatchQueue.main.async {
                        self.setDisplayOverrideHeld(ok)
                    }
                } else {
                    PrivilegedShell.sendCommand("display_disable")
                    DispatchQueue.main.async {
                        self.setDisplayOverrideHeld(false)
                    }
                }
                DispatchQueue.main.async {
                    self.startCaffeinate(holdDisplay: self.shouldHoldDisplay)
                    self.updateUI(active: self.isActive)
                }
            }
        } else {
            updateUI(active: isActive)
        }
    }

    // MARK: - Auto Lock

    @objc func toggleAllowAutoLock() {
        setAllowAutoLock(!allowAutoLock)
        syncAutoLock()
        updateUI(active: isActive)
    }

    func syncAutoLock() {
        if isActive && shouldHoldAutoLock {
            applyAutoLockOverride()
        } else {
            restoreAutoLockOverride()
        }
    }

    func applyAutoLockOverride() {
        guard !UserDefaults.standard.bool(forKey: autoLockOverrideActiveKey) else { return }
        guard let defaults = screensaverDefaults else { return }

        // NSNumber covers Double / Int / Bool-adjacent plist numbers from com.apple.screensaver.
        if let saved = defaults.object(forKey: "askForPasswordDelay") as? NSNumber {
            UserDefaults.standard.set(true, forKey: autoLockSavedHadKeyKey)
            UserDefaults.standard.set(saved.doubleValue, forKey: autoLockSavedDelayKey)
        } else {
            UserDefaults.standard.set(false, forKey: autoLockSavedHadKeyKey)
            UserDefaults.standard.removeObject(forKey: autoLockSavedDelayKey)
        }

        UserDefaults.standard.set(true, forKey: autoLockOverrideActiveKey)
        defaults.set(autoLockOverrideDelay, forKey: "askForPasswordDelay")
        defaults.synchronize()
    }

    func restoreAutoLockOverride() {
        guard UserDefaults.standard.bool(forKey: autoLockOverrideActiveKey) else { return }
        guard let defaults = screensaverDefaults else { return }

        if UserDefaults.standard.bool(forKey: autoLockSavedHadKeyKey) {
            let saved = UserDefaults.standard.double(forKey: autoLockSavedDelayKey)
            defaults.set(saved, forKey: "askForPasswordDelay")
        } else {
            defaults.removeObject(forKey: "askForPasswordDelay")
        }
        defaults.synchronize()

        UserDefaults.standard.set(false, forKey: autoLockOverrideActiveKey)
    }

    // MARK: - Download Monitor

    @objc func toggleDownloadMonitor() {
        downloadMonitorEnabled.toggle()
        UserDefaults.standard.set(downloadMonitorEnabled, forKey: downloadMonitorKey)
        downloadMonitorSince = downloadMonitorEnabled ? Date() : nil

        if downloadMonitorEnabled {
            startDownloadMonitor()
        } else {
            stopDownloadMonitor()
            removeWakeReason(.downloads)
        }

        updateUI(active: isActive)
    }

    func startDownloadMonitor() {
        stopDownloadMonitor()
        downloadMonitorTimer = Timer(timeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.checkDownloads()
        }
        RunLoop.main.add(downloadMonitorTimer!, forMode: .common)
    }

    func stopDownloadMonitor() {
        downloadMonitorTimer?.invalidate()
        downloadMonitorTimer = nil
    }

    func checkDownloads() {
        guard downloadMonitorEnabled else { return }

        if hasActiveDownloads() {
            addWakeReason(.downloads)
        } else {
            removeWakeReason(.downloads)
        }
    }

    func hasActiveDownloads() -> Bool {
        let downloadProcesses = ["curl", "wget", "aria2c", "httpdownloader"]

        for name in downloadProcesses {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            task.arguments = ["-x", name]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()
                if task.terminationStatus == 0 {
                    return true
                }
            } catch {
                continue
            }
        }

        return hasRecentDownloadsFolderActivity()
    }

    func hasRecentDownloadsFolderActivity() -> Bool {
        let fileManager = FileManager.default
        guard let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            return false
        }

        let partialSuffixes = [".part", ".download", ".crdownload"]
        let recentWindow: TimeInterval = 30
        let now = Date()

        let contents = (try? fileManager.contentsOfDirectory(
            at: downloads,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: []
        )) ?? []

        for url in contents {
            let name = url.lastPathComponent.lowercased()
            if partialSuffixes.contains(where: { name.hasSuffix($0) }) {
                return true
            }

            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  now.timeIntervalSince(modified) < recentWindow else {
                continue
            }
            return true
        }

        return false
    }

    // MARK: - Stay Awake While App Active

    @objc func toggleStayAwakeForApp(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? WatchableApp else { return }

        if watchdog.toggleWatching(app) {
            UserDefaults.standard.set(app.bundleIdentifier, forKey: "ClamKeepWatchdogBundleID")
            UserDefaults.standard.set(app.name, forKey: "ClamKeepWatchdogAppName")
            watchedAppSince = Date()
            addWakeReason(.app)
        } else {
            UserDefaults.standard.removeObject(forKey: "ClamKeepWatchdogBundleID")
            UserDefaults.standard.removeObject(forKey: "ClamKeepWatchdogAppName")
            watchedAppSince = nil
            removeWakeReason(.app)
        }

        rebuildMenu()
    }

}

// MARK: - AppWatchdogDelegate

extension AppDelegate: AppWatchdogDelegate {
    func watchdogDidDetectAppTermination(_ watchdog: AppWatchdog, app: WatchableApp) {
        UserDefaults.standard.removeObject(forKey: "ClamKeepWatchdogBundleID")
        UserDefaults.standard.removeObject(forKey: "ClamKeepWatchdogAppName")
        watchedAppSince = nil
        removeWakeReason(.app)
        rebuildMenu()
    }
}
