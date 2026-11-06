import AppKit

/// Windows (settings, helper setup, custom timer), the quit confirmation and the
/// settings commands sent from SwiftUI.
extension AppDelegate {

    private enum WindowID {
        static let helperSetup = "helper-setup"
        static let customTimer = "custom-timer"
    }

    // MARK: - Model

    func configureModel() {
        model.commands = self
        model.launchAtLogin = LoginItem.isEnabled()
        model.showSystemStats = showSystemMetrics
        model.language = L.current
        model.iconStyle = IconStyle.current
        model.tintIcon = MenuBarIcon.tintWhenActive
        model.confirmQuit = AppModel.confirmQuitStored
    }

    // MARK: - Wake toggle (header switch and ⌘W)

    @objc func handleWakeToggle() {
        // Without the helper an enable would fail after retries — offer setup instead.
        if !isActive && !isEnablingWake && model.helper.needsInstall {
            presentHelperSetup()
            refreshLiveTimers()
            return
        }
        toggleWake()
        refreshLiveTimers()
    }

    // MARK: - Settings and About

    @objc func openSettings() {
        model.launchAtLogin = LoginItem.isEnabled()
        settingsWindow.show(.general)
    }

    @objc func openAbout() {
        settingsWindow.show(.about)
    }

    // MARK: - Helper

    func refreshHelperState(presentSetupIfNeeded: Bool) {
        HelperInstaller.detectState { [weak self] state in
            guard let self else { return }
            self.model.helper = state
            self.refreshLiveTimers()
            if presentSetupIfNeeded && state.needsInstall {
                self.presentHelperSetup()
            }
        }
    }

    func presentHelperSetup() {
        WindowPresenter.shared.present(id: WindowID.helperSetup, title: L.onboardingTitle, transparentTitlebar: true) {
            HelperSetupView(model: model,
                            onInstall: { [weak self] in self?.installHelper() },
                            onClose: { WindowPresenter.shared.close(WindowID.helperSetup) })
        }
    }

    // MARK: - Custom timer

    @objc func promptCustomTimer() {
        let initial = autoOffMinutes ?? 30
        WindowPresenter.shared.present(id: WindowID.customTimer, title: L.timerCustomTitle) {
            CustomTimerView(initialMinutes: initial,
                            onStart: { [weak self] minutes in
                                self?.startCustomTimer(minutes: minutes)
                                WindowPresenter.shared.close(WindowID.customTimer)
                            },
                            onCancel: { WindowPresenter.shared.close(WindowID.customTimer) })
        }
    }

    private func startCustomTimer(minutes: Int) {
        // Same effect as before the redesign: a fresh deadline, and Wake Mode on if needed.
        autoOffDeadline = nil
        autoOffMinutes = minutes
        if !isActive {
            addWakeReason(.manual)
        }
        rebuildMenu()
    }

    // MARK: - Quit

    @objc func quitApp() {
        guard isActive, model.confirmQuit else {
            if isActive { performWakeTeardownSync() }
            NSApp.terminate(nil)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L.quitConfirmTitle
        alert.informativeText = L.quitConfirmMessage
        alert.alertStyle = .warning
        let quit = alert.addButton(withTitle: L.quitAndTurnOff)
        quit.hasDestructiveAction = true
        alert.addButton(withTitle: L.cancelButton)
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = L.dontAskAgain

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if alert.suppressionButton?.state == .on {
            setConfirmQuit(false)
        }
        performWakeTeardownSync()
        NSApp.terminate(nil)
    }
}

// MARK: - AppCommands

extension AppDelegate: AppCommands {
    func setLaunchAtLogin(_ enabled: Bool) {
        if enabled != LoginItem.isEnabled() {
            _ = LoginItem.toggle()
        }
        // Registration can require approval in System Settings — show what's real.
        model.launchAtLogin = LoginItem.isEnabled()
    }

    func setShowSystemStats(_ enabled: Bool) {
        showSystemMetrics = enabled
        UserDefaults.standard.set(enabled, forKey: showSystemMetricsKey)
        statusHeader.showsMetrics = enabled
        if enabled {
            SystemMetrics.warmUp()
            refreshSystemMetrics()
        }
        model.showSystemStats = enabled
    }

    func setLanguage(_ language: Language) {
        L.current = language
        model.language = language
        relocalizeMenu()
        MainMenu.install(target: self, settings: #selector(openSettings), quit: #selector(quitApp))
        if showSystemMetrics { refreshSystemMetrics() }
        if let window = WindowPresenter.shared.window("helper-setup") { window.title = L.onboardingTitle }
        if let window = WindowPresenter.shared.window("custom-timer") { window.title = L.timerCustomTitle }
    }

    func setIconStyle(_ style: IconStyle) {
        IconStyle.current = style
        model.iconStyle = style
        updateStatusIcon(active: isActive)
    }

    func setTintIcon(_ enabled: Bool) {
        MenuBarIcon.tintWhenActive = enabled
        model.tintIcon = enabled
        updateStatusIcon(active: isActive)
    }

    func setConfirmQuit(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: AppModel.confirmQuitKey)
        model.confirmQuit = enabled
    }

    func installHelper() {
        guard model.helper != .installing else { return }
        let previous = model.helper
        model.helper = .installing
        refreshLiveTimers()
        HelperInstaller.install { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                // The daemon can take a moment to answer IPC; trust the installer result.
                self.model.helper = .installed(version: HelperInstaller.expectedVersion)
                self.refreshLiveTimers()
            case .failure(let failure) where failure.cancelled:
                // Cancelling the password prompt is a choice, not an error.
                self.model.helper = previous == .checking ? .missing : previous
                self.refreshLiveTimers()
            case .failure(let failure):
                self.model.helper = .failed(details: failure.details)
                self.refreshLiveTimers()
            }
        }
    }
}
