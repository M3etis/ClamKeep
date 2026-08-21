import Foundation

enum PrivilegedShell {

    private static let triggerDir = "/tmp/clamkeep"
    private static let triggerFile = "\(triggerDir)/command"
    private static let resultFile = "\(triggerDir)/command.result"

    static func setup() {
        try? FileManager.default.createDirectory(atPath: triggerDir, withIntermediateDirectories: true)
    }

    @discardableResult
    static func sendCommand(_ command: String) -> Bool {
        setup()

        // Remove old result
        try? FileManager.default.removeItem(atPath: resultFile)

        // Write trigger
        do {
            try command.write(toFile: triggerFile, atomically: true, encoding: .utf8)
        } catch {
            NSLog("ClamKeep: Failed to write trigger: \(error)")
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

        NSLog("ClamKeep: Daemon timeout")
        return false
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
            return nil
        }
    }
}
