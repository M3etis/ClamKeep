import Foundation
import os.log

private let logger = Logger(subsystem: "com.m3etis.clamkeep", category: "ipc")

enum PrivilegedShell {

    private static let ipcDir = "/Library/Application Support/com.m3etis.clamkeep"
    private static let triggerFile = "\(ipcDir)/command"
    private static let resultFile = "\(ipcDir)/command.result"
    /// One trigger/result pair on disk — concurrent requests would clobber each other.
    private static let requestLock = NSLock()

    /// Sends a helper command and returns the raw response, or nil on failure.
    /// The IPC dir is sticky and owned by root, so we may be unable to delete a
    /// previous result — accept only a response written strictly after this request.
    private static func request(_ command: String) -> String? {
        requestLock.lock()
        defer { requestLock.unlock() }

        do {
            try FileManager.default.createDirectory(atPath: ipcDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o733])
        } catch {
            logger.error("Failed to create IPC directory: \(error.localizedDescription)")
            return nil
        }

        // Snapshot the previous result mtime — a root-owned result file cannot
        // always be deleted, so a stale response must never be accepted.
        let preMtime: Date = {
            let attrs = try? FileManager.default.attributesOfItem(atPath: resultFile)
            return (attrs?[.modificationDate] as? Date) ?? .distantPast
        }()
        let startedAt = Date()
        try? FileManager.default.removeItem(atPath: resultFile)

        do {
            try command.write(toFile: triggerFile, atomically: true, encoding: .utf8)
            // Helper rejects world-writable triggers; 0600 is also the intended mode.
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: triggerFile)
        } catch {
            logger.error("Failed to write trigger: \(error.localizedDescription)")
            return nil
        }

        let deadline = Date().addingTimeInterval(5.0)
        while Date() < deadline {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: resultFile),
               let modified = attrs[.modificationDate] as? Date,
               modified > preMtime,
               modified >= startedAt.addingTimeInterval(-0.05),
               let result = try? String(contentsOfFile: resultFile, encoding: .utf8),
               !result.isEmpty {
                return result
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        logger.error("Daemon timeout for command: \(command, privacy: .public)")
        return nil
    }

    @discardableResult
    static func sendCommand(_ command: String) -> Bool {
        guard let result = request(command) else { return false }
        return result.hasPrefix("ok 0")
    }

    static func getDaemonVersion() -> String? {
        guard let result = request("version") else { return nil }
        let parts = result.split(separator: " ", maxSplits: 1)
        if parts.count >= 2 {
            return String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    static func isSleepDisabled() -> Bool {
        guard let output = runCommand("/usr/bin/pmset", arguments: ["-g"]) else {
            return false
        }
        return output.contains("SleepDisabled\t\t1") || output.contains("disablesleep 1")
    }

    static func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            logger.error("Failed to run command \(path, privacy: .public): \(error.localizedDescription)")
            return nil
        }
    }
}
