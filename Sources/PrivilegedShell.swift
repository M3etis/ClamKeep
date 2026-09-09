import Foundation
import os.log

private let logger = Logger(subsystem: "com.m3etis.clamkeep", category: "ipc")

enum PrivilegedShell {

    private static let ipcDir = "/Library/Application Support/com.m3etis.clamkeep"
    private static let triggerFile = "\(ipcDir)/command"
    private static let resultFile = "\(ipcDir)/command.result"

    @discardableResult
    static func sendCommand(_ command: String) -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: ipcDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o733])
        } catch {
            logger.error("Failed to create IPC directory: \(error.localizedDescription)")
            return false
        }

        // Remove old result
        try? FileManager.default.removeItem(atPath: resultFile)

        // Write trigger with restricted permissions
        do {
            try command.write(toFile: triggerFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: triggerFile)
        } catch {
            logger.error("Failed to write trigger: \(error.localizedDescription)")
            return false
        }

        // Poll for result
        let deadline = Date().addingTimeInterval(5.0)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: resultFile) {
                if let result = try? String(contentsOfFile: resultFile, encoding: .utf8) {
                    try? FileManager.default.removeItem(atPath: resultFile)
                    return result.hasPrefix("ok 0") || result.hasPrefix("ok 1")
                }
            }
            Thread.sleep(forTimeInterval: 0.2)
        }

        logger.error("Daemon timeout for command: \(command, privacy: .public)")
        return false
    }

    static func getDaemonVersion() -> String? {
        do {
            try FileManager.default.createDirectory(atPath: ipcDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o733])
        } catch {
            logger.error("Failed to create IPC directory: \(error.localizedDescription)")
            return nil
        }

        try? FileManager.default.removeItem(atPath: resultFile)
        do {
            try "version".write(toFile: triggerFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: triggerFile)
        } catch {
            logger.error("Failed to write version trigger: \(error.localizedDescription)")
            return nil
        }

        let deadline = Date().addingTimeInterval(5.0)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: resultFile) {
                if let result = try? String(contentsOfFile: resultFile, encoding: .utf8) {
                    try? FileManager.default.removeItem(atPath: resultFile)
                    let parts = result.split(separator: " ", maxSplits: 1)
                    if parts.count >= 2 {
                        return String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            Thread.sleep(forTimeInterval: 0.2)
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
