import AppKit

/// Status item and menu. Only presentation lives here — every item calls the
/// same actions on `AppDelegate` that the pre-redesign menu used.
extension AppDelegate {

    // MARK: - Status item

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.toolTip = "ClamKeep"
        updateStatusIcon(active: false)
    }

    func updateStatusIcon(active: Bool) {
        let state: MenuBarIconState = !active ? .inactive : (shouldHoldDisplay ? .active : .activeDisplaySleepAllowed)
        statusItem.button?.image = MenuBarIcon.image(style: IconStyle.current, state: state)
        statusItem.button?.setAccessibilityLabel(MenuBarIcon.accessibilityDescription(for: state))
    }

    // MARK: - Menu

    func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        // Enabled state is set explicitly in updateUI(); auto-enabling would
        // also disable the action-less header and dim its controls.
        menu.autoenablesItems = false

        // Header: status + Wake Mode switch (primary action) + metrics + helper banner.
        statusHeader = StatusHeaderView()
        statusHeader.showsMetrics = showSystemMetrics
        statusHeader.onToggleWake = { [weak self] _ in self?.handleWakeToggle() }
        statusHeader.onInstallHelper = { [weak self] in self?.presentHelperSetup() }
        headerMenuItem = NSMenuItem()
        headerMenuItem.view = statusHeader
        menu.addItem(headerMenuItem)

        // The header switch can't be reached with the arrow keys; this row keeps Wake Mode
        // reachable from the keyboard and VoiceOver, and shows the ⌘W shortcut.
        wakeMenuItem = item(L.menuTurnOnWake, #selector(handleWakeToggle), key: "w")
        menu.addItem(wakeMenuItem)

        menu.addItem(.separator())

        allowDisplaySleepMenuItem = item(L.menuAllowDisplaySleep, #selector(toggleAllowDisplaySleep), key: "s")
        menu.addItem(allowDisplaySleepMenuItem)
        allowAutoLockMenuItem = item(L.menuAllowAutoLock, #selector(toggleAllowAutoLock), key: "l")
        menu.addItem(allowAutoLockMenuItem)

        menu.addItem(.separator())

        downloadMonitorMenuItem = item(L.menuDownloads, #selector(toggleDownloadMonitor), key: "d")
        menu.addItem(downloadMonitorMenuItem)

        stayAwakeMenuItem = NSMenuItem(title: L.menuWhileAppRuns, action: nil, keyEquivalent: "")
        stayAwakeSubmenu = NSMenu()
        stayAwakeSubmenu.delegate = self
        stayAwakeMenuItem.submenu = stayAwakeSubmenu
        menu.addItem(stayAwakeMenuItem)

        timerSubmenuItem = NSMenuItem(title: L.menuTurnOffAfter, action: nil, keyEquivalent: "")
        timerSubmenu = NSMenu()
        timerSubmenu.delegate = self
        timerSubmenuItem.submenu = timerSubmenu
        menu.addItem(timerSubmenuItem)

        menu.addItem(.separator())

        menu.addItem(item(L.menuSettings, #selector(openSettings), key: ","))
        menu.addItem(item(L.menuAbout, #selector(openAbout)))
        menu.addItem(item(L.menuQuit, #selector(quitApp), key: "q"))

        statusItem.menu = menu
        updateUI(active: isActive)
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    /// Kept for the call sites in the wake logic; the menu no longer needs rebuilding.
    func rebuildMenu() {
        updateUI(active: isActive)
    }

    /// Rebuilds titles after a language change.
    func relocalizeMenu() {
        setupMenu()
        settingsWindow.relocalize()
    }

    // MARK: - State → UI

    func updateUI(active: Bool) {
        wakeMenuItem.title = active ? L.menuTurnOffWake : L.menuTurnOnWake
        // Checkmarks replace the old colored "[ON]" badges.
        // Exceptions only mean something while Wake Mode holds the Mac.
        allowDisplaySleepMenuItem.isEnabled = active
        allowAutoLockMenuItem.isEnabled = active
        allowDisplaySleepMenuItem.state = (allowDisplaySleep && active) ? .on : .off
        allowAutoLockMenuItem.state = (allowAutoLock && active) ? .on : .off
        downloadMonitorMenuItem.state = downloadMonitorEnabled ? .on : .off
        stayAwakeMenuItem.state = watchdog.isWatching ? .on : .off
        timerSubmenuItem.state = (autoOffMinutes != nil && active) ? .on : .off
        updateStatusIcon(active: active)
        refreshLiveTimers()
    }

    /// Called every second while Wake Mode is on.
    func refreshLiveTimers() {
        statusHeader.apply(headerState())
    }

    private func headerState() -> StatusHeaderState {
        let mode: StatusHeaderState.Mode
        if isEnablingWake {
            mode = .turningOn
        } else if isActive {
            mode = shouldHoldDisplay ? .on : .onDisplayMaySleep
        } else {
            mode = .off
        }

        let subtitle: String
        if isActive, let deadline = autoOffDeadline {
            subtitle = L.statusRemaining(Self.clock(Int(deadline.timeIntervalSinceNow)))
        } else if isActive {
            subtitle = L.statusElapsed(formattedDuration(since: wakeStartTime, long: true))
        } else {
            subtitle = L.statusHint
        }

        var banner: String?
        switch model.helper {
        case .missing: banner = L.helperMissingBanner
        case .outdated: banner = L.helperOutdatedBanner
        default: banner = nil
        }
        return StatusHeaderState(mode: mode, subtitle: subtitle, helperBanner: banner)
    }

    /// HH:MM:SS — shared by the elapsed and remaining timers.
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    func refreshSystemMetrics() {
        guard showSystemMetrics else { return }
        statusHeader.reloadMetrics(SystemMetrics.snapshot())
    }

    // MARK: - Submenus

    func populateTimerSubmenu() {
        timerSubmenu.removeAllItems()

        let never = item(L.menuNever, #selector(setAutoOffOff))
        never.state = autoOffMinutes == nil ? .on : .off
        timerSubmenu.addItem(never)
        timerSubmenu.addItem(.separator())

        for minutes in Self.timerPresets {
            let preset = item(L.duration(minutes: minutes), #selector(setAutoOffPreset(_:)))
            preset.representedObject = minutes
            preset.state = autoOffMinutes == minutes ? .on : .off
            timerSubmenu.addItem(preset)
        }
        timerSubmenu.addItem(.separator())

        // A stored value outside the presets (custom, or an old 5-min step) stays visible and checked.
        if let current = autoOffMinutes, !Self.timerPresets.contains(current) {
            let custom = item(L.menuCustomCurrent(L.duration(minutes: current)), #selector(promptCustomTimer))
            custom.state = .on
            timerSubmenu.addItem(custom)
        } else {
            timerSubmenu.addItem(item(L.timerCustom, #selector(promptCustomTimer)))
        }
    }

    func populateStayAwakeSubmenu() {
        stayAwakeSubmenu.removeAllItems()

        if watchdog.isWatching, let watched = watchdog.watchedApp {
            let sinceText = formattedDuration(since: watchedAppSince, long: false)
            let label = NSMenuItem(title: "\(L.watchingApp(watched.name)) · \(sinceText)", action: nil, keyEquivalent: "")
            label.isEnabled = false
            stayAwakeSubmenu.addItem(label)
            stayAwakeSubmenu.addItem(.separator())
        }

        let apps = AppWatchdog.runningUserApps(excludingBundleID: Bundle.main.bundleIdentifier)
        if apps.isEmpty {
            // Empty state: say what's missing and what to do next.
            for text in [L.menuNoApps, L.menuNoAppsHint] {
                let info = NSMenuItem(title: text, action: nil, keyEquivalent: "")
                info.isEnabled = false
                stayAwakeSubmenu.addItem(info)
            }
            return
        }

        for app in apps {
            let entry = item(app.name, #selector(toggleStayAwakeForApp(_:)))
            entry.representedObject = app
            entry.state = (watchdog.watchedApp?.bundleIdentifier == app.bundleIdentifier) ? .on : .off
            if let icon = NSRunningApplication(processIdentifier: app.processIdentifier)?.icon {
                icon.size = NSSize(width: 16, height: 16)
                entry.image = icon
            }
            stayAwakeSubmenu.addItem(entry)
        }
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // State can change in the background (downloads, watched app, helper).
        updateUI(active: isActive)
        if menu === stayAwakeSubmenu { populateStayAwakeSubmenu() }
        if menu === timerSubmenu { populateTimerSubmenu() }
        if menu === statusItem.menu { refreshSystemMetrics() }
    }
}
