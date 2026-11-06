import AppKit
import Combine

/// Commands the SwiftUI windows send back to the app. Implemented by `AppDelegate`,
/// which owns all business logic and persistence.
protocol AppCommands: AnyObject {
    func setLaunchAtLogin(_ enabled: Bool)
    func setShowSystemStats(_ enabled: Bool)
    func setLanguage(_ language: Language)
    func setIconStyle(_ style: IconStyle)
    func setTintIcon(_ enabled: Bool)
    func setConfirmQuit(_ enabled: Bool)
    func installHelper()
}

/// Observable mirror of user-facing settings for the SwiftUI windows.
/// Views read from it and write through `commands`; the delegate pushes back
/// the value actually applied (e.g. a login item that needs approval).
final class AppModel: ObservableObject {
    static let confirmQuitKey = "ClamKeepConfirmQuit"

    @Published var launchAtLogin = false
    @Published var showSystemStats = true
    @Published var language: Language = L.current
    @Published var iconStyle: IconStyle = IconStyle.current
    @Published var tintIcon = MenuBarIcon.tintWhenActive
    @Published var confirmQuit = true
    @Published var helper: HelperState = .checking
    /// Details of the last failed install attempt. Kept separate from `helper`,
    /// so a failed reinstall never hides a helper that is still installed.
    @Published var installError: String?

    weak var commands: AppCommands?

    static var confirmQuitStored: Bool {
        UserDefaults.standard.object(forKey: confirmQuitKey) as? Bool ?? true
    }
}
