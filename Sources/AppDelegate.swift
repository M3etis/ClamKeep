import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var timerMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!

    private var isActive = false
    private var wakeStartTime: Date?
    private var displayTimer: Timer?

    private let wakeStartKey = "ClamKeepWakeStartTime"

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()

        if !isDaemonInstalled() {
            installDaemon()
        }

        checkInitialState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isActive {
            disableWakeMode()
        }
    }

    // MARK: - Daemon

    private func isDaemonInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: "/Library/LaunchDaemons/com.m3etis.clamkeep.helper.plist") &&
               FileManager.default.fileExists(atPath: "/usr/local/bin/clamkeep-helper.sh")
    }

    private func installDaemon() {
        let alert = NSAlert()
        alert.messageText = L.installTitle
        alert.informativeText = L.installMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.installButton)
        alert.addButton(withTitle: L.cancelButton)

        if alert.runModal() == .alertFirstButtonReturn {
            let bundlePath = Bundle.main.resourcePath ?? ""
            let tempDir = "/tmp/clamkeep-install"
            try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(atPath: "\(bundlePath)/clamkeep-helper.sh", toPath: "\(tempDir)/clamkeep-helper.sh")
            try? FileManager.default.copyItem(atPath: "\(bundlePath)/install-helper.sh", toPath: "\(tempDir)/install-helper.sh")

            let script = "do shell script \"bash \\\"\(tempDir)/install-helper.sh\\\"\" with administrator privileges"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    let msg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    NSLog("ClamKeep: Install failed: \(msg)")
                    let failAlert = NSAlert()
                    failAlert.messageText = L.installErrorTitle
                    failAlert.informativeText = msg
                    failAlert.alertStyle = .warning
                    failAlert.addButton(withTitle: "OK")
                    failAlert.runModal()
                }
            }
            try? FileManager.default.removeItem(atPath: tempDir)
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = makeIcon(active: false)
            button.toolTip = "ClamKeep"
        }
    }

    // MARK: - Menu

    private func setupMenu() {
        let menu = NSMenu()

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
        menu.addItem(toggleMenuItem)

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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let sleepDisabled = PrivilegedShell.isSleepDisabled()
            DispatchQueue.main.async {
                guard let self = self else { return }
                if sleepDisabled {
                    self.isActive = true
                    self.wakeStartTime = UserDefaults.standard.object(forKey: self.wakeStartKey) as? Date ?? Date()
                    self.updateUI(active: true)
                    self.startDisplayTimer()
                }
            }
        }
    }

    private func updateUI(active: Bool) {
        statusMenuItem.title = active ? L.statusActive : L.statusInactive
        toggleMenuItem.title = active ? L.disableWake : L.enableWake
        timerMenuItem.isHidden = !active
        statusItem.button?.image = makeIcon(active: active)
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
        let success = PrivilegedShell.sendCommand("enable")
        if success {
            isActive = true
            wakeStartTime = Date()
            UserDefaults.standard.set(wakeStartTime, forKey: wakeStartKey)
            updateUI(active: true)
            startDisplayTimer()
        }
    }

    private func disableWakeMode() {
        let success = PrivilegedShell.sendCommand("disable")
        if success {
            isActive = false
            wakeStartTime = nil
            UserDefaults.standard.removeObject(forKey: wakeStartKey)
            updateUI(active: false)
            stopDisplayTimer()
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

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = L.aboutTitle
        alert.informativeText = L.aboutDescription
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
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

    // MARK: - Icon

    private func makeIcon(active: Bool) -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Shield
            let shield = NSBezierPath()
            shield.move(to: CGPoint(x: 9, y: 17))
            shield.curve(to: CGPoint(x: 16, y: 14),
                         controlPoint1: CGPoint(x: 12, y: 17),
                         controlPoint2: CGPoint(x: 16, y: 16))
            shield.line(to: CGPoint(x: 16, y: 7.5))
            shield.curve(to: CGPoint(x: 9, y: 1.5),
                         controlPoint1: CGPoint(x: 16, y: 4.5),
                         controlPoint2: CGPoint(x: 13, y: 2))
            shield.curve(to: CGPoint(x: 2, y: 7.5),
                         controlPoint1: CGPoint(x: 5, y: 2),
                         controlPoint2: CGPoint(x: 2, y: 4.5))
            shield.line(to: CGPoint(x: 2, y: 14))
            shield.curve(to: CGPoint(x: 9, y: 17),
                         controlPoint1: CGPoint(x: 2, y: 16),
                         controlPoint2: CGPoint(x: 6, y: 17))
            shield.close()

            if active {
                // Bright green accent when active
                NSColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0).setFill()
            } else {
                NSColor.white.withAlphaComponent(0.75).setFill()
            }
            shield.fill()

            // Moon crescent
            if active {
                NSColor(white: 0.15, alpha: 1).setFill()
            } else {
                NSColor(white: 0.35, alpha: 1).setFill()
            }
            let outer = NSBezierPath(ovalIn: NSRect(x: 5.5, y: 5, width: 9, height: 9))
            outer.fill()

            if active {
                NSColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0).setFill()
            } else {
                NSColor.white.withAlphaComponent(0.75).setFill()
            }
            let inner = NSBezierPath(ovalIn: NSRect(x: 7.2, y: 4.5, width: 9, height: 9))
            inner.fill()

            return true
        }
        image.isTemplate = false
        return image
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
}
