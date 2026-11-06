import AppKit
import os.log

private let logger = Logger(subsystem: "com.m3etis.clamkeep", category: "helper")

/// UI-facing state of the privileged helper daemon.
enum HelperState: Equatable {
    case checking
    case installed(version: String)
    case missing
    case outdated(installed: String?)
    case installing
    case failed(details: String)

    var needsInstall: Bool {
        switch self {
        case .missing, .outdated, .failed: return true
        default: return false
        }
    }
}

struct HelperInstallFailure: Error {
    /// The user dismissed the administrator password prompt.
    let cancelled: Bool
    let details: String
}

/// Detects and installs the launchd helper. Same files, script and checks as before
/// the redesign — only moved out of the app delegate so the UI can drive it.
enum HelperInstaller {
    static let expectedVersion = "1.4.0"
    private static let plistPath = "/Library/LaunchDaemons/com.m3etis.clamkeep.helper.plist"
    private static let scriptPath = "/usr/local/bin/clamkeep-helper.sh"

    /// Blocking (talks to the helper over IPC) — call off the main thread.
    static func detectState() -> HelperState {
        let fm = FileManager.default
        guard fm.fileExists(atPath: plistPath), fm.fileExists(atPath: scriptPath) else { return .missing }
        let version = PrivilegedShell.getDaemonVersion()
        return version == expectedVersion ? .installed(version: expectedVersion) : .outdated(installed: version)
    }

    static func detectState(completion: @escaping (HelperState) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let state = detectState()
            DispatchQueue.main.async { completion(state) }
        }
    }

    /// Runs the bundled installer with administrator privileges. Completes on the main queue.
    static func install(completion: @escaping (Result<Void, HelperInstallFailure>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = runInstaller()
            DispatchQueue.main.async { completion(result) }
        }
    }

    private static func runInstaller() -> Result<Void, HelperInstallFailure> {
        let bundlePath = Bundle.main.resourcePath ?? ""
        let tempDir = NSTemporaryDirectory() + "clamkeep-install-\(UUID().uuidString)"
        defer {
            do {
                try FileManager.default.removeItem(atPath: tempDir)
            } catch {
                logger.warning("Failed to clean up temp dir: \(error.localizedDescription)")
            }
        }
        do {
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            try FileManager.default.copyItem(atPath: "\(bundlePath)/clamkeep-helper.sh", toPath: "\(tempDir)/clamkeep-helper.sh")
            try FileManager.default.copyItem(atPath: "\(bundlePath)/install-helper.sh", toPath: "\(tempDir)/install-helper.sh")
        } catch {
            logger.error("Failed to prepare install scripts: \(error.localizedDescription)")
            return .failure(HelperInstallFailure(cancelled: false,
                                                 details: "\(L.helperPrepareFailed)\n\(error.localizedDescription)"))
        }

        let escapedPrompt = L.promptExplanation
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"bash \\\"\(tempDir)/install-helper.sh\\\"\" with administrator privileges with prompt \"\(escapedPrompt)\""
        guard let appleScript = NSAppleScript(source: script) else {
            return .failure(HelperInstallFailure(cancelled: false, details: "NSAppleScript could not be created"))
        }
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            let number = error[NSAppleScript.errorNumber] as? Int
            logger.error("Daemon setup failed: \(message)")
            // -128: "User canceled." from the authorization prompt.
            return .failure(HelperInstallFailure(cancelled: number == -128,
                                                 details: number.map { "\(message) (\($0))" } ?? message))
        }
        return .success(())
    }
}
