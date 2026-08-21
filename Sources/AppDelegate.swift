import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var toggleMenuItem: NSMenuItem!
    private var timerMenuItem: NSMenuItem!
    private var statusMenuItem: NSMenuItem!
    private var loginMenuItem: NSMenuItem!

    private var isActive = false
    private var wakeStartTime: Date?
    private var displayTimer: Timer?

    private let wakeStartKey = "ClamKeepWakeStartTime"

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()

        // Install helper daemon if not present
        if !isDaemonInstalled() {
            installDaemon()
        }

        checkInitialState()

        NSLog("ClamKeep: Launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isActive {
            disableWakeMode()
        }
    }

    // MARK: - Setup

    private func isDaemonInstalled() -> Bool {
        let plistPath = "/Library/LaunchDaemons/com.m3etis.clamkeep.helper.plist"
        let helperPath = "/usr/local/bin/clamkeep-helper.sh"
        return FileManager.default.fileExists(atPath: plistPath) &&
               FileManager.default.fileExists(atPath: helperPath)
    }

    private func installDaemon() {
        let alert = NSAlert()
        alert.messageText = "Установка компонента"
        alert.informativeText = "ClamKeep нужно установить фоновый компонент для управления сном без запроса пароля.\n\nПотребуется пароль администратора (один раз)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Установить")
        alert.addButton(withTitle: "Отмена")

        if alert.runModal() == .alertFirstButtonReturn {
            // Get the path to helper files in the app bundle
            let bundlePath = Bundle.main.resourcePath ?? ""
            let helperScript = "\(bundlePath)/clamkeep-helper.sh"
            let installScript = "\(bundlePath)/install-helper.sh"

            // Copy helper to temp location and run install with sudo
            let tempDir = "/tmp/clamkeep-install"
            try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(atPath: helperScript, toPath: "\(tempDir)/clamkeep-helper.sh")
            try? FileManager.default.copyItem(atPath: installScript, toPath: "\(tempDir)/install-helper.sh")

            let script = "do shell script \"bash \\\"\(tempDir)/install-helper.sh\\\"\" with administrator privileges"

            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    let msg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    NSLog("ClamKeep: Install failed: \(msg)")
                    let failAlert = NSAlert()
                    failAlert.messageText = "Ошибка установки"
                    failAlert.informativeText = msg
                    failAlert.alertStyle = .warning
                    failAlert.addButton(withTitle: "OK")
                    failAlert.runModal()
                } else {
                    NSLog("ClamKeep: Daemon installed successfully")
                }
            }

            try? FileManager.default.removeItem(atPath: tempDir)
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = makeIcon(active: false)
            button.toolTip = "ClamKeep"
        }
    }

    private func makeIcon(active: Bool) -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let color = active ? NSColor.white : NSColor.white.withAlphaComponent(0.8)

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
            color.setFill()
            shield.fill()

            // Moon crescent - drawn as two overlapping circles
            let bgColor = active ? NSColor(white: 0.15, alpha: 1) : NSColor(white: 0.3, alpha: 1)
            bgColor.setFill()

            // Outer circle (full moon)
            let outer = NSBezierPath(ovalIn: NSRect(x: 5.5, y: 5, width: 9, height: 9))
            outer.fill()

            // Inner circle (cutout) - creates crescent effect
            color.setFill()
            let inner = NSBezierPath(ovalIn: NSRect(x: 7.2, y: 4.5, width: 9, height: 9))
            inner.fill()

            return true
        }
        image.isTemplate = false
        return image
    }

    private func setupMenu() {
        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "Режим сна: стандартный", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        timerMenuItem = NSMenuItem(title: "Время работы: 00:00:00", action: nil, keyEquivalent: "")
        timerMenuItem.isHidden = true
        timerMenuItem.isEnabled = false
        menu.addItem(timerMenuItem)

        menu.addItem(NSMenuItem.separator())

        toggleMenuItem = NSMenuItem(title: "Включить бодрствование", action: #selector(toggleWake), keyEquivalent: "w")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(NSMenuItem.separator())

        loginMenuItem = NSMenuItem(title: "Запускать при входе в систему", action: #selector(toggleLogin), keyEquivalent: "")
        loginMenuItem.target = self
        loginMenuItem.state = LoginItem.isEnabled() ? .on : .off
        menu.addItem(loginMenuItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "О приложении", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Выход", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - State Management

    private func checkInitialState() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let sleepDisabled = PrivilegedShell.isSleepDisabled()

            DispatchQueue.main.async {
                guard let self = self else { return }

                if sleepDisabled {
                    self.isActive = true
                    self.wakeStartTime = UserDefaults.standard.object(forKey: self.wakeStartKey) as? Date ?? Date()
                    self.updateUIForActiveState()
                    self.startDisplayTimer()
                }
            }
        }
    }

    private func updateUIForActiveState() {
        statusMenuItem.title = "Режим сна: отключён"
        toggleMenuItem.title = "Выключить бодрствование"
        timerMenuItem.isHidden = false
        updateIcon(active: true)
        updateTimerDisplay()
    }

    private func updateUIForInactiveState() {
        statusMenuItem.title = "Режим сна: стандартный"
        toggleMenuItem.title = "Включить бодрствование"
        timerMenuItem.isHidden = true
        updateIcon(active: false)
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
            updateUIForActiveState()
            startDisplayTimer()
        }
    }

    private func disableWakeMode() {
        let success = PrivilegedShell.sendCommand("disable")
        if success {
            isActive = false
            wakeStartTime = nil
            UserDefaults.standard.removeObject(forKey: wakeStartKey)
            updateUIForInactiveState()
            stopDisplayTimer()
        }
    }

    @objc private func toggleLogin() {
        let enabled = LoginItem.toggle()
        loginMenuItem.state = enabled ? .on : .off
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "ClamKeep"
        alert.informativeText = "Версия 1.0.0\n\nПредотвращает уход Mac в сон при закрытой крышке.\n\nАвтор: m3etis@gmail.com"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quitApp() {
        if isActive {
            let alert = NSAlert()
            alert.messageText = "Бодрствование активно"
            alert.informativeText = "Режим бодрствования будет отключён перед выходом. Продолжить?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Выйти")
            alert.addButton(withTitle: "Отмена")

            if alert.runModal() == .alertFirstButtonReturn {
                disableWakeMode()
                NSApp.terminate(nil)
            }
        } else {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Icon

    private func updateIcon(active: Bool) {
        statusItem.button?.image = makeIcon(active: active)
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
            timerMenuItem.title = String(format: "Время работы: %dд %02d:%02d:%02d", days, remHours, minutes, seconds)
        } else {
            timerMenuItem.title = String(format: "Время работы: %02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}
