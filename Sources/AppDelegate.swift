import AppKit
import os.log

private let logger = Logger(subsystem: "com.m3etis.clamkeep", category: "app")

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var timerMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!
    private var keepScreenOnMenuItem: NSMenuItem!
    private var stayAwakeSubmenu: NSMenu!

    private var isActive = false
    private var wakeStartTime: Date?
    private var displayTimer: Timer?
    private var caffeinateProcess: Process?
    private var allowDisplaySleep = false
    private let allowDisplaySleepKey = "ClamKeepAllowDisplaySleep"

    private var watchdog = AppWatchdog()

    private let wakeStartKey = "ClamKeepWakeStartTime"
    private let expectedDaemonVersion = "1.3.0"

    func applicationDidFinishLaunching(_ notification: Notification) {
        watchdog.delegate = self
        setupStatusItem()
        setupMenu()

        if !isDaemonInstalled() || !isDaemonUpToDate() {
            setupDaemon()
        }

        checkInitialState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isActive {
            disableWakeMode()
        }
        stopCaffeinate()
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
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        timerMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        timerMenuItem.isHidden = true
        timerMenuItem.isEnabled = false
        menu.addItem(timerMenuItem)

        menu.addItem(NSMenuItem.separator())

        toggleMenuItem = NSMenuItem(title: L.enableWake, action: #selector(toggleWake), keyEquivalent: "w")
        toggleMenuItem.target = self
        toggleMenuItem.state = isActive ? .on : .off
        menu.addItem(toggleMenuItem)

        // Allow Display Sleep toggle
        keepScreenOnMenuItem = NSMenuItem(title: L.keepScreenOn, action: #selector(toggleKeepScreenOn), keyEquivalent: "s")
        keepScreenOnMenuItem.target = self
        keepScreenOnMenuItem.state = allowDisplaySleep ? .on : .off
        keepScreenOnMenuItem.isEnabled = isActive
        menu.addItem(keepScreenOnMenuItem)

        // Stay Awake Until submenu
        let stayAwakeItem = NSMenuItem(title: L.stayAwakeUntil, action: nil, keyEquivalent: "")
        stayAwakeSubmenu = NSMenu()
        stayAwakeSubmenu.delegate = self
        stayAwakeItem.submenu = stayAwakeSubmenu
        menu.addItem(stayAwakeItem)

        menu.addItem(NSMenuItem.separator())

        // Settings submenu
        let settingsItem = NSMenuItem(title: L.settings, action: nil, keyEquivalent: ",")
        let settingsMenu = NSMenu()

        // Launch at login
        let loginItem = NSMenuItem(title: L.launchAtLogin, action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LoginItem.isEnabled() ? .on : .off
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

    private func checkInitialState() {
        allowDisplaySleep = UserDefaults.standard.bool(forKey: allowDisplaySleepKey)

        // Restore watchdog target if persisted
        if let bundleID = UserDefaults.standard.string(forKey: "ClamKeepWatchdogBundleID"),
           let name = UserDefaults.standard.string(forKey: "ClamKeepWatchdogAppName") {
            let pid = NSWorkspace.shared.runningApplications
                .first { $0.bundleIdentifier == bundleID }?.processIdentifier ?? 0
            if pid != 0 {
                let app = WatchableApp(bundleIdentifier: bundleID, name: name, processIdentifier: pid)
                watchdog.startWatching(app)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let sleepDisabled = PrivilegedShell.isSleepDisabled()
            DispatchQueue.main.async {
                guard let self = self else { return }
                if sleepDisabled {
                    self.isActive = true
                    self.wakeStartTime = UserDefaults.standard.object(forKey: self.wakeStartKey) as? Date ?? Date()
                    self.startCaffeinate()
                    self.updateUI(active: true)
                    self.startDisplayTimer()
                }
            }
        }
    }

    private func updateUI(active: Bool) {
        statusMenuItem.title = active ? L.statusActive : L.statusInactive
        toggleMenuItem.title = active ? L.disableWake : L.enableWake
        toggleMenuItem.state = active ? .on : .off
        timerMenuItem.isHidden = !active
        keepScreenOnMenuItem.isEnabled = active
        keepScreenOnMenuItem.state = allowDisplaySleep ? .on : .off

        if active && allowDisplaySleep {
            statusItem.button?.image = IconRenderer.makeIcon(style: IconStyle.current, active: true, displaySleepAllowed: true)
            statusMenuItem.title = L.statusActiveDisplaySleep
        } else {
            statusItem.button?.image = IconRenderer.makeIcon(style: IconStyle.current, active: active, displaySleepAllowed: false)
        }
        if active { updateTimerDisplay() }
    }

    // MARK: - Actions

    @objc private func toggleWake() {
        if isActive {
            disableWakeMode()
        } else {
            enableWakeMode()
        }
    }

    private func enableWakeMode() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let sleepOk = PrivilegedShell.sendCommand("enable")
            if !self.allowDisplaySleep {
                let displayOk = PrivilegedShell.sendCommand("display_enable")
                if !displayOk {
                    logger.error("display_enable failed, sleep prevention still active")
                }
            }
            DispatchQueue.main.async {
                if sleepOk {
                    self.isActive = true
                    self.wakeStartTime = Date()
                    UserDefaults.standard.set(self.wakeStartTime, forKey: self.wakeStartKey)
                    self.startCaffeinate()
                    self.updateUI(active: true)
                    self.startDisplayTimer()
                }
            }
        }
    }

    private func disableWakeMode() {
        stopCaffeinate()
        watchdog.stopWatching()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let sleepOk = PrivilegedShell.sendCommand("disable")
            if !self.allowDisplaySleep {
                PrivilegedShell.sendCommand("display_disable")
            }
            DispatchQueue.main.async {
                if sleepOk {
                    self.isActive = false
                    self.wakeStartTime = nil
                    UserDefaults.standard.removeObject(forKey: self.wakeStartKey)
                    self.updateUI(active: false)
                    self.stopDisplayTimer()
                }
            }
        }
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
                disableWakeMode()
                NSApp.terminate(nil)
            }
        } else {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Caffeinate

    private func startCaffeinate() {
        stopCaffeinate()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        if allowDisplaySleep {
            process.arguments = ["-i"]
        } else {
            process.arguments = ["-u", "-i"]
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] _ in
            guard let self = self, self.isActive else { return }
            logger.warning("caffeinate exited unexpectedly, restarting")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.isActive {
                    self.startCaffeinate()
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
        guard let startTime = wakeStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60

        if hours >= 24 {
            let days = hours / 24
            let remHours = hours % 24
            timerMenuItem.title = "\(L.wakeTime): \(days)d \(String(format: "%02d:%02d:%02d", remHours, minutes, seconds))"
        } else {
            timerMenuItem.title = "\(L.wakeTime): \(String(format: "%02d:%02d:%02d", hours, minutes, seconds))"
        }
    }

    // MARK: - Allow Display Sleep

    @objc private func toggleKeepScreenOn() {
        allowDisplaySleep.toggle()
        UserDefaults.standard.set(allowDisplaySleep, forKey: allowDisplaySleepKey)

        if isActive {
            stopCaffeinate()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                if self.allowDisplaySleep {
                    PrivilegedShell.sendCommand("display_disable")
                } else {
                    PrivilegedShell.sendCommand("display_enable")
                }
                DispatchQueue.main.async {
                    self.startCaffeinate()
                    self.updateUI(active: self.isActive)
                }
            }
        } else {
            updateUI(active: isActive)
        }
    }

    // MARK: - Stay Awake Until

    @objc private func toggleStayAwakeForApp(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? WatchableApp else { return }

        if watchdog.toggleWatching(app) {
            // Persist watchdog target
            UserDefaults.standard.set(app.bundleIdentifier, forKey: "ClamKeepWatchdogBundleID")
            UserDefaults.standard.set(app.name, forKey: "ClamKeepWatchdogAppName")
            if !isActive {
                enableWakeMode()
            }
        } else {
            UserDefaults.standard.removeObject(forKey: "ClamKeepWatchdogBundleID")
            UserDefaults.standard.removeObject(forKey: "ClamKeepWatchdogAppName")
        }

        rebuildMenu()
    }

    private func populateStayAwakeSubmenu() {
        stayAwakeSubmenu.removeAllItems()

        if watchdog.isWatching, let watched = watchdog.watchedApp {
            let label = NSMenuItem(title: L.watchingApp(watched.name), action: nil, keyEquivalent: "")
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
        if menu === stayAwakeSubmenu {
            populateStayAwakeSubmenu()
        }
    }
}

// MARK: - Menu Validation

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem == keepScreenOnMenuItem {
            return isActive
        }
        return menuItem.isEnabled
    }
}

// MARK: - AppWatchdogDelegate

extension AppDelegate: AppWatchdogDelegate {
    func watchdogDidDetectAppTermination(_ watchdog: AppWatchdog, app: WatchableApp) {
        UserDefaults.standard.removeObject(forKey: "ClamKeepWatchdogBundleID")
        UserDefaults.standard.removeObject(forKey: "ClamKeepWatchdogAppName")
        if isActive {
            disableWakeMode()
        }
        rebuildMenu()
    }
}
