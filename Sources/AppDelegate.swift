import AppKit
import os.log

private let logger = Logger(subsystem: "com.m3etis.clamkeep", category: "app")

private struct WakeReason: OptionSet {
    let rawValue: Int
    static let manual    = WakeReason(rawValue: 1 << 0)
    static let downloads = WakeReason(rawValue: 1 << 1)
    static let app       = WakeReason(rawValue: 1 << 2)
}

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var timerMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!
    private var allowDisplaySleepMenuItem: NSMenuItem!
    private var allowAutoLockMenuItem: NSMenuItem!
    private var downloadMonitorMenuItem: NSMenuItem!
    private var stayAwakeMenuItem: NSMenuItem!
    private var stayAwakeSubmenu: NSMenu!
    private var timerSubmenuItem: NSMenuItem!
    private var timerSubmenu: NSMenu!

    private var isActive = false
    private var wakeStartTime: Date?
    private var displayTimer: Timer?
    private var caffeinateProcess: Process?
    private var allowDisplaySleep = false
    private let allowDisplaySleepKey = "ClamKeepAllowDisplaySleep"
    /// Display hold is the default Wake Mode behavior; Allow Display Sleep turns it off.
    private var shouldHoldDisplay: Bool { !allowDisplaySleep }
    private var downloadMonitorEnabled = false
    private let downloadMonitorKey = "ClamKeepDownloadMonitor"
    private var downloadMonitorTimer: Timer?

    private var autoOffMinutes: Int? {
        didSet {
            if let minutes = autoOffMinutes {
                UserDefaults.standard.set(minutes, forKey: autoOffMinutesKey)
                autoOffDeadline = Date().addingTimeInterval(TimeInterval(minutes) * 60)
            } else {
                UserDefaults.standard.removeObject(forKey: autoOffMinutesKey)
                autoOffDeadline = nil
            }
        }
    }
    private var autoOffDeadline: Date?
    private let autoOffMinutesKey = "ClamKeepAutoOffMinutes"
    private static let timerPresets = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]

    private var allowAutoLock = false
    private let allowAutoLockKey = "ClamKeepAllowAutoLock"
    /// Auto-lock hold is the default Wake Mode behavior; Allow Auto Lock turns it off.
    private var shouldHoldAutoLock: Bool { !allowAutoLock }
    private let autoLockOverrideActiveKey = "ClamKeepAutoLockOverrideActive"
    private let autoLockSavedDelayKey = "ClamKeepAutoLockSavedDelay"
    private let autoLockSavedHadKeyKey = "ClamKeepAutoLockSavedHadKey"
    private let autoLockOverrideDelay = 315_360_000.0

    private var allowDisplaySleepSince: Date?
    private var allowAutoLockSince: Date?
    private var downloadMonitorSince: Date?
    private var watchedAppSince: Date?

    private var wakeReasons: WakeReason = []
    private var displayOverrideHeld = false
    private let displayOverrideHeldKey = "ClamKeepDisplayOverrideHeld"
    private var isEnablingWake = false

    private var watchdog = AppWatchdog()

    private let wakeStartKey = "ClamKeepWakeStartTime"
    private let expectedDaemonVersion = "1.3.0"

    private var screensaverDefaults: UserDefaults? {
        UserDefaults(suiteName: "com.apple.screensaver")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        watchdog.delegate = self
        setupStatusItem()
        setupMenu()
        migrateAllowFlags()

        if !isDaemonInstalled() || !isDaemonUpToDate() {
            setupDaemon()
        }

        checkInitialState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        performWakeTeardownSync()
    }

    // MARK: - Daemon

    private func isDaemonInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: "/Library/LaunchDaemons/com.m3etis.clamkeep.helper.plist") &&
               FileManager.default.fileExists(atPath: "/usr/local/bin/clamkeep-helper.sh")
    }

    private func isDaemonUpToDate() -> Bool {
        let installed = PrivilegedShell.getDaemonVersion()
        return installed == expectedDaemonVersion
    }

    private func setupDaemon() {
        let alert = NSAlert()
        alert.messageText = L.setupTitle
        alert.informativeText = L.setupMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.setupButton)
        alert.addButton(withTitle: L.cancelButton)

        if alert.runModal() == .alertFirstButtonReturn {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.executeInstallScript()
            }
        }
    }

    private func executeInstallScript() {
        let bundlePath = Bundle.main.resourcePath ?? ""
        let tempDir = NSTemporaryDirectory() + "clamkeep-install-\(UUID().uuidString)"
        do {
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.copyItem(atPath: "\(bundlePath)/clamkeep-helper.sh", toPath: "\(tempDir)/clamkeep-helper.sh")
            try FileManager.default.copyItem(atPath: "\(bundlePath)/install-helper.sh", toPath: "\(tempDir)/install-helper.sh")
        } catch {
            logger.error("Failed to prepare install scripts: \(error.localizedDescription)")
            return
        }

        let escapedPrompt = L.promptExplanation
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"bash \\\"\(tempDir)/install-helper.sh\\\"\" with administrator privileges with prompt \"\(escapedPrompt)\""
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error = error {
                let msg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                logger.error("Daemon setup failed: \(msg)")
                DispatchQueue.main.async {
                    let failAlert = NSAlert()
                    failAlert.messageText = L.setupErrorTitle
                    failAlert.informativeText = msg
                    failAlert.alertStyle = .warning
                    failAlert.addButton(withTitle: L.okButton)
                    failAlert.runModal()
                }
            }
        }
        do {
            try FileManager.default.removeItem(atPath: tempDir)
        } catch {
            logger.warning("Failed to clean up temp dir: \(error.localizedDescription)")
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = IconRenderer.makeIcon(style: IconStyle.current, active: false)
            button.toolTip = "ClamKeep"
        }
    }

    // MARK: - Menu

    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self

        statusMenuItem = NSMenuItem(title: L.statusInactive, action: nil, keyEquivalent: "")
        setMenuItem(statusMenuItem, title: L.statusInactive, active: false, enabled: false)
        menu.addItem(statusMenuItem)

        timerMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        timerMenuItem.isHidden = true
        timerMenuItem.isEnabled = false
        menu.addItem(timerMenuItem)

        menu.addItem(NSMenuItem.separator())

        toggleMenuItem = NSMenuItem(title: L.wakeMode, action: #selector(toggleWake), keyEquivalent: "w")
        toggleMenuItem.target = self
        setMenuItem(toggleMenuItem, title: L.wakeMode, active: isActive, shortcut: "w", since: isActive ? wakeStartTime : nil)
        menu.addItem(toggleMenuItem)

        // Allow Display Sleep toggle (exception while Wake Mode is on)
        allowDisplaySleepMenuItem = NSMenuItem(title: L.allowDisplaySleep, action: #selector(toggleAllowDisplaySleep), keyEquivalent: "s")
        allowDisplaySleepMenuItem.target = self
        setMenuItem(allowDisplaySleepMenuItem, title: L.allowDisplaySleep, active: allowDisplaySleep && isActive, enabled: isActive, shortcut: "s", since: (allowDisplaySleep && isActive) ? allowDisplaySleepSince : nil)
        menu.addItem(allowDisplaySleepMenuItem)

        // Allow Auto Lock toggle (exception while Wake Mode is on)
        allowAutoLockMenuItem = NSMenuItem(title: L.allowAutoLock, action: #selector(toggleAllowAutoLock), keyEquivalent: "l")
        allowAutoLockMenuItem.target = self
        setMenuItem(allowAutoLockMenuItem, title: L.allowAutoLock, active: allowAutoLock && isActive, enabled: isActive, shortcut: "l", since: (allowAutoLock && isActive) ? allowAutoLockSince : nil)
        menu.addItem(allowAutoLockMenuItem)

        // Don't Sleep During Downloads toggle
        downloadMonitorMenuItem = NSMenuItem(title: L.dontSleepDuringDownloads, action: #selector(toggleDownloadMonitor), keyEquivalent: "d")
        downloadMonitorMenuItem.target = self
        setMenuItem(downloadMonitorMenuItem, title: L.dontSleepDuringDownloads, active: downloadMonitorEnabled, shortcut: "d", since: downloadMonitorEnabled ? downloadMonitorSince : nil)
        menu.addItem(downloadMonitorMenuItem)

        // Auto-off timer submenu
        timerSubmenuItem = NSMenuItem(title: L.timerMenu, action: nil, keyEquivalent: "")
        timerSubmenu = NSMenu()
        timerSubmenu.delegate = self
        timerSubmenuItem.submenu = timerSubmenu
        setMenuItem(timerSubmenuItem, title: L.timerMenu, active: autoOffMinutes != nil)
        menu.addItem(timerSubmenuItem)

        // Stay Awake While App Active submenu
        stayAwakeMenuItem = NSMenuItem(title: L.stayAwakeUntil, action: nil, keyEquivalent: "")
        stayAwakeSubmenu = NSMenu()
        stayAwakeSubmenu.delegate = self
        stayAwakeMenuItem.submenu = stayAwakeSubmenu
        setMenuItem(stayAwakeMenuItem, title: L.stayAwakeUntil, active: watchdog.isWatching, since: watchdog.isWatching ? watchedAppSince : nil)
        menu.addItem(stayAwakeMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Settings submenu
        let settingsItem = NSMenuItem(title: L.settings, action: nil, keyEquivalent: ",")
        let settingsMenu = NSMenu()

        // Launch at login
        let loginItem = NSMenuItem(title: L.launchAtLogin, action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        setMenuItem(loginItem, title: L.launchAtLogin, active: LoginItem.isEnabled())
        settingsMenu.addItem(loginItem)

        settingsMenu.addItem(NSMenuItem.separator())

        // Language submenu
        let langItem = NSMenuItem(title: L.language, action: nil, keyEquivalent: "")
        let langMenu = NSMenu()

        for lang in Language.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang.rawValue
            item.state = L.current == lang ? .on : .off
            langMenu.addItem(item)
        }
        langItem.submenu = langMenu
        settingsMenu.addItem(langItem)

        // Icon submenu
        let iconItem = NSMenuItem(title: L.iconStyle, action: nil, keyEquivalent: "")
        let iconMenu = NSMenu()
        for style in IconStyle.allCases {
            let item = NSMenuItem(title: style.localizedName, action: #selector(changeIcon(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            item.state = IconStyle.current == style ? .on : .off
            item.image = IconRenderer.makeIcon(style: style, active: false)
            iconMenu.addItem(item)
        }
        iconItem.submenu = iconMenu
        settingsMenu.addItem(iconItem)

        settingsItem.submenu = settingsMenu
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: L.about, action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: L.quit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func rebuildMenu() {
        statusItem.menu = nil
        setupMenu()
    }

    // MARK: - State

    /// One-time invert of 1.6 Prevent* prefs into Allow* exceptions.
    /// Fresh installs default to both Allow OFF (= hold display + hold auto lock).
    private func migrateAllowFlags() {
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

    private func checkInitialState() {
        allowDisplaySleep = UserDefaults.standard.bool(forKey: allowDisplaySleepKey)
        downloadMonitorEnabled = UserDefaults.standard.bool(forKey: downloadMonitorKey)
        allowAutoLock = UserDefaults.standard.bool(forKey: allowAutoLockKey)
        displayOverrideHeld = UserDefaults.standard.bool(forKey: displayOverrideHeldKey)
        if UserDefaults.standard.object(forKey: autoOffMinutesKey) != nil {
            autoOffMinutes = UserDefaults.standard.integer(forKey: autoOffMinutesKey)
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
                    if self.allowDisplaySleep { self.allowDisplaySleepSince = self.wakeStartTime }
                    if self.allowAutoLock { self.allowAutoLockSince = self.wakeStartTime }
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

    private func updateUI(active: Bool) {
        updateHeaderHints()
        setMenuItem(toggleMenuItem, title: L.wakeMode, active: active, shortcut: "w", since: active ? wakeStartTime : nil)
        // Allow rows show green ON only while the exception is live (Wake Mode on).
        setMenuItem(allowDisplaySleepMenuItem, title: L.allowDisplaySleep, active: allowDisplaySleep && active, enabled: active, shortcut: "s", since: (allowDisplaySleep && active) ? allowDisplaySleepSince : nil)
        setMenuItem(allowAutoLockMenuItem, title: L.allowAutoLock, active: allowAutoLock && active, enabled: active, shortcut: "l", since: (allowAutoLock && active) ? allowAutoLockSince : nil)
        setMenuItem(downloadMonitorMenuItem, title: L.dontSleepDuringDownloads, active: downloadMonitorEnabled, shortcut: "d", since: downloadMonitorEnabled ? downloadMonitorSince : nil)
        setMenuItem(timerSubmenuItem, title: L.timerMenu, active: autoOffMinutes != nil && active, enabled: true)
        setMenuItem(stayAwakeMenuItem, title: L.stayAwakeUntil, active: watchdog.isWatching, since: watchdog.isWatching ? watchedAppSince : nil)

        if active && !shouldHoldDisplay {
            statusItem.button?.image = IconRenderer.makeIcon(style: IconStyle.current, active: true, displaySleepAllowed: true)
        } else {
            statusItem.button?.image = IconRenderer.makeIcon(style: IconStyle.current, active: active, displaySleepAllowed: false)
        }
        refreshLiveTimers()
    }

    private func updateHeaderHints() {
        var modes: [String] = []
        if isActive { modes.append(L.modeWake) }
        if isActive && shouldHoldDisplay { modes.append(L.modeDisplay) }
        if isActive && allowDisplaySleep { modes.append(L.modeDisplayMaySleep) }
        if isActive && shouldHoldAutoLock { modes.append(L.modeNoAutoLock) }
        if isActive && allowAutoLock { modes.append(L.modeAutoLockAllowed) }
        if wakeReasons.contains(.downloads) { modes.append(L.modeDownloads) }
        if watchdog.isWatching, let name = watchdog.watchedApp?.name {
            modes.append(L.modeApp(name))
        }

        let title: String
        if modes.isEmpty {
            title = L.statusInactive
        } else {
            title = "\(L.activeModesPrefix) \(modes.joined(separator: " · "))"
        }
        setMenuItem(statusMenuItem, title: title, active: false, enabled: false)

        if isActive {
            let text: String
            if let deadline = autoOffDeadline {
                let remaining = max(0, Int(deadline.timeIntervalSinceNow))
                let hours = remaining / 3600
                let minutes = (remaining % 3600) / 60
                let seconds = remaining % 60
                text = "\(L.wakeTimeRemaining): \(String(format: "%02d:%02d:%02d", hours, minutes, seconds))"
            } else {
                let elapsed = formattedDuration(since: wakeStartTime, long: true)
                text = "\(L.wakeTime): \(elapsed)"
            }
            timerMenuItem.attributedTitle = NSAttributedString(string: text, attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.secondaryLabelColor
            ])
            timerMenuItem.title = text
            timerMenuItem.isHidden = false
        } else {
            timerMenuItem.isHidden = true
        }
    }

    /// Active toggles are shown in green instead of a checkmark.
    /// Shade is tuned per appearance so the label stays readable in menus.
    private var activeToggleColor: NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(srgbRed: 0.45, green: 0.90, blue: 0.50, alpha: 1)
                : NSColor(srgbRed: 0.08, green: 0.52, blue: 0.24, alpha: 1)
        }
    }

    private func setMenuItem(_ item: NSMenuItem, title: String, active: Bool, enabled: Bool = true, shortcut: String? = nil, since: Date? = nil) {
        let color: NSColor = !enabled
            ? .disabledControlTextColor
            : (active ? activeToggleColor : .labelColor)
        let menuFont = NSFont.menuFont(ofSize: 0)
        let font: NSFont = (active && enabled)
            ? NSFontManager.shared.convert(menuFont, toHaveTrait: .boldFontMask)
            : menuFont

        item.view = nil
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: font,
            .foregroundColor: color
        ])
        item.title = title

        if active {
            // Live toggles only: ON while this option is in effect.
            item.keyEquivalent = "ON"
            item.keyEquivalentModifierMask = []
        } else if let shortcut {
            item.keyEquivalent = shortcut
            item.keyEquivalentModifierMask = [.command]
        } else {
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
        }

        item.state = .off
        item.isEnabled = enabled
    }

    private func formattedDuration(since: Date?, long: Bool) -> String {
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

    private func refreshLiveTimers() {
        updateHeaderHints()
        if isActive {
            setMenuItem(toggleMenuItem, title: L.wakeMode, active: true, shortcut: "w", since: wakeStartTime)
        }
        if allowDisplaySleep && isActive {
            setMenuItem(allowDisplaySleepMenuItem, title: L.allowDisplaySleep, active: true, enabled: true, shortcut: "s", since: allowDisplaySleepSince)
        }
        if allowAutoLock && isActive {
            setMenuItem(allowAutoLockMenuItem, title: L.allowAutoLock, active: true, enabled: true, shortcut: "l", since: allowAutoLockSince)
        }
        if downloadMonitorEnabled {
            setMenuItem(downloadMonitorMenuItem, title: L.dontSleepDuringDownloads, active: true, shortcut: "d", since: downloadMonitorSince)
        }
        if autoOffMinutes != nil && isActive {
            setMenuItem(timerSubmenuItem, title: L.timerMenu, active: true)
        }
        if watchdog.isWatching {
            setMenuItem(stayAwakeMenuItem, title: L.stayAwakeUntil, active: true, since: watchedAppSince)
        }
    }

    // MARK: - Auto-off Timer

    private func populateTimerSubmenu() {
        timerSubmenu.removeAllItems()

        let offItem = NSMenuItem(title: L.timerOff, action: #selector(setAutoOffOff), keyEquivalent: "")
        offItem.target = self
        offItem.state = autoOffMinutes == nil ? .on : .off
        timerSubmenu.addItem(offItem)

        timerSubmenu.addItem(NSMenuItem.separator())

        for minutes in Self.timerPresets {
            let item = NSMenuItem(title: L.timerMinutes(minutes), action: #selector(setAutoOffPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = minutes
            item.state = autoOffMinutes == minutes ? .on : .off
            timerSubmenu.addItem(item)
        }

        timerSubmenu.addItem(NSMenuItem.separator())

        let customItem = NSMenuItem(title: L.timerCustom, action: #selector(promptCustomTimer), keyEquivalent: "")
        customItem.target = self
        timerSubmenu.addItem(customItem)
    }

    @objc private func setAutoOffOff() {
        autoOffMinutes = nil
        rebuildMenu()
    }

    @objc private func setAutoOffPreset(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        autoOffMinutes = minutes
        if !isActive {
            addWakeReason(.manual)
        }
        rebuildMenu()
    }

    @objc private func promptCustomTimer() {
        let alert = NSAlert()
        alert.messageText = L.timerCustomTitle
        alert.informativeText = L.timerCustomMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.okButton)
        alert.addButton(withTitle: L.cancelButton)

        // Frame-based accessory: NSAlert manages accessoryView's frame and
        // breaks when Auto Layout is enabled on the view itself.
        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 60))

        let hoursLabel = NSTextField(labelWithString: L.timerHoursLabel)
        hoursLabel.frame = NSRect(x: 0, y: 32, width: 70, height: 22)

        let hoursField = NSTextField(frame: NSRect(x: 78, y: 30, width: 70, height: 24))
        hoursField.stringValue = "0"

        let minutesLabel = NSTextField(labelWithString: L.timerMinutesLabel)
        minutesLabel.frame = NSRect(x: 0, y: 4, width: 70, height: 22)

        let minutesField = NSTextField(frame: NSRect(x: 78, y: 2, width: 70, height: 24))
        minutesField.stringValue = "30"

        accessory.addSubview(hoursLabel)
        accessory.addSubview(hoursField)
        accessory.addSubview(minutesLabel)
        accessory.addSubview(minutesField)

        alert.accessoryView = accessory
        alert.layout()
        alert.window.initialFirstResponder = hoursField

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let hours = max(0, hoursField.integerValue)
        let minutes = max(0, min(59, minutesField.integerValue))
        let total = hours * 60 + minutes
        guard total > 0 else {
            autoOffMinutes = nil
            rebuildMenu()
            return
        }
        autoOffMinutes = total
        if !isActive {
            addWakeReason(.manual)
        }
        rebuildMenu()
    }

    private func checkAutoOff() {
        guard let deadline = autoOffDeadline, Date() >= deadline else { return }
        clearAllWakeReasons()
        rebuildMenu()
    }

    // MARK: - Wake Reasons

    private func addWakeReason(_ reason: WakeReason) {
        wakeReasons.insert(reason)
        if !isActive {
            enableWakeMode()
        }
    }

    private func removeWakeReason(_ reason: WakeReason) {
        wakeReasons.remove(reason)
        if wakeReasons.isEmpty {
            disableWakeMode()
        }
    }

    private func clearAllWakeReasons() {
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
        disableWakeMode()
    }

    // MARK: - Actions

    @objc private func toggleWake() {
        if isActive {
            clearAllWakeReasons()
        } else {
            addWakeReason(.manual)
        }
    }

    private func enableWakeMode() {
        if isActive || isEnablingWake { return }
        isEnablingWake = true
        let holdDisplay = shouldHoldDisplay
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let sleepOk = PrivilegedShell.sendCommand("enable")
            if !sleepOk {
                logger.error("enable command failed")
            }
            if holdDisplay {
                let displayOk = PrivilegedShell.sendCommand("display_enable")
                DispatchQueue.main.async {
                    self.setDisplayOverrideHeld(displayOk)
                }
                if !displayOk {
                    logger.error("display_enable failed, sleep prevention still active")
                }
            }
            DispatchQueue.main.async {
                self.isEnablingWake = false
                if sleepOk {
                    self.isActive = true
                    self.wakeStartTime = Date()
                    UserDefaults.standard.set(self.wakeStartTime, forKey: self.wakeStartKey)
                    self.startCaffeinate(holdDisplay: self.shouldHoldDisplay)
                    self.updateUI(active: true)
                    self.startDisplayTimer()
                    self.syncAutoLock()
                }
            }
        }
    }

    private func disableWakeMode() {
        stopCaffeinate()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let sleepOk = PrivilegedShell.sendCommand("disable")
            if self.displayOverrideHeld {
                PrivilegedShell.sendCommand("display_disable")
                DispatchQueue.main.async {
                    self.setDisplayOverrideHeld(false)
                }
            }
            DispatchQueue.main.async {
                if sleepOk {
                    self.isActive = false
                    self.wakeStartTime = nil
                    UserDefaults.standard.removeObject(forKey: self.wakeStartKey)
                    // Wake is off — auto-off timer has nothing to count down.
                    self.autoOffMinutes = nil
                    self.updateUI(active: false)
                    self.stopDisplayTimer()
                    self.syncAutoLock()
                }
            }
        }
    }

    private func performWakeTeardownSync() {
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

    @objc private func toggleLogin() {
        let _ = LoginItem.toggle()
        rebuildMenu()
    }

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let lang = Language(rawValue: raw) else { return }
        L.current = lang
        updateUI(active: isActive)
        rebuildMenu()
    }

    @objc private func changeIcon(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let style = IconStyle(rawValue: raw) else { return }
        IconStyle.current = style
        updateUI(active: isActive)
        rebuildMenu()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = L.aboutTitle
        alert.informativeText = L.aboutDescription
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.githubButton)
        alert.addButton(withTitle: L.okButton)
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "https://github.com/M3etis/ClamKeep") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func quitApp() {
        if isActive {
            let alert = NSAlert()
            alert.messageText = L.quitConfirmTitle
            alert.informativeText = L.quitConfirmMessage
            alert.alertStyle = .warning
            alert.addButton(withTitle: L.quitButton)
            alert.addButton(withTitle: L.cancelButton)
            if alert.runModal() == .alertFirstButtonReturn {
                performWakeTeardownSync()
                NSApp.terminate(nil)
            }
        } else {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Caffeinate

    private func startCaffeinate(holdDisplay: Bool) {
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

    private func stopCaffeinate() {
        if let process = caffeinateProcess, process.isRunning {
            process.terminationHandler = nil
            process.terminate()
        }
        caffeinateProcess = nil
    }

    // MARK: - Timer

    private func startDisplayTimer() {
        stopDisplayTimer()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimerDisplay()
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func updateTimerDisplay() {
        checkAutoOff()
        refreshLiveTimers()
    }

    // MARK: - Allow Display Sleep

    /// Keeps `pmset displaysleep` in sync with the Allow flag while Wake Mode is held.
    private func syncDisplayHold() {
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

    private func setDisplayOverrideHeld(_ held: Bool) {
        displayOverrideHeld = held
        UserDefaults.standard.set(held, forKey: displayOverrideHeldKey)
    }

    @objc private func toggleAllowDisplaySleep() {
        allowDisplaySleep.toggle()
        UserDefaults.standard.set(allowDisplaySleep, forKey: allowDisplaySleepKey)
        allowDisplaySleepSince = allowDisplaySleep ? Date() : nil

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

    // MARK: - Allow Auto Lock

    @objc private func toggleAllowAutoLock() {
        allowAutoLock.toggle()
        UserDefaults.standard.set(allowAutoLock, forKey: allowAutoLockKey)
        allowAutoLockSince = allowAutoLock ? Date() : nil
        syncAutoLock()
        updateUI(active: isActive)
    }

    private func syncAutoLock() {
        if isActive && shouldHoldAutoLock {
            applyAutoLockOverride()
        } else {
            restoreAutoLockOverride()
        }
    }

    private func applyAutoLockOverride() {
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

    private func restoreAutoLockOverride() {
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

    @objc private func toggleDownloadMonitor() {
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

    private func startDownloadMonitor() {
        stopDownloadMonitor()
        downloadMonitorTimer = Timer(timeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.checkDownloads()
        }
        RunLoop.main.add(downloadMonitorTimer!, forMode: .common)
    }

    private func stopDownloadMonitor() {
        downloadMonitorTimer?.invalidate()
        downloadMonitorTimer = nil
    }

    private func checkDownloads() {
        guard downloadMonitorEnabled else { return }

        if hasActiveDownloads() {
            addWakeReason(.downloads)
        } else {
            removeWakeReason(.downloads)
        }
    }

    private func hasActiveDownloads() -> Bool {
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

    private func hasRecentDownloadsFolderActivity() -> Bool {
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

    @objc private func toggleStayAwakeForApp(_ sender: NSMenuItem) {
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

    private func populateStayAwakeSubmenu() {
        stayAwakeSubmenu.removeAllItems()

        if watchdog.isWatching, let watched = watchdog.watchedApp {
            let sinceText = formattedDuration(since: watchedAppSince, long: false)
            let label = NSMenuItem(title: "\(L.watchingApp(watched.name))  \(sinceText)", action: nil, keyEquivalent: "")
            label.isEnabled = false
            stayAwakeSubmenu.addItem(label)
            stayAwakeSubmenu.addItem(NSMenuItem.separator())
        }

        let apps = AppWatchdog.runningUserApps(excludingBundleID: Bundle.main.bundleIdentifier)

        if apps.isEmpty {
            let emptyItem = NSMenuItem(title: L.noRunningApps, action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            stayAwakeSubmenu.addItem(emptyItem)
            return
        }

        for app in apps {
            let item = NSMenuItem(title: app.name, action: #selector(toggleStayAwakeForApp(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = app
            item.state = (watchdog.watchedApp?.bundleIdentifier == app.bundleIdentifier) ? .on : .off

            if let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) {
                item.image = runningApp.icon
                item.image?.size = NSSize(width: 16, height: 16)
            }

            stayAwakeSubmenu.addItem(item)
        }
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refreshLiveTimers()
        if menu === stayAwakeSubmenu {
            populateStayAwakeSubmenu()
        }
        if menu === timerSubmenu {
            populateTimerSubmenu()
        }
    }
}

// MARK: - Menu Validation

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem == allowDisplaySleepMenuItem || menuItem == allowAutoLockMenuItem {
            return isActive
        }
        return true
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
