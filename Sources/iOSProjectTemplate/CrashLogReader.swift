import Foundation

// MARK: - CrashLogReader

/// Reads crash information and writes a human-readable report to `crashlog.txt`.
public struct CrashLogReader {

    public let outputDirectory: URL

    public init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }

    // MARK: - Public API

    /// Write `crashInfo` to `crashlog.txt` inside `outputDirectory`.
    /// - Returns: The URL of the written file.
    @discardableResult
    public func writeCrashLog(_ crashInfo: CrashInfo) throws -> URL {
        let logURL = outputDirectory.appendingPathComponent("crashlog.txt")

        var existingContent = ""
        if FileManager.default.fileExists(atPath: logURL.path),
           let data = FileManager.default.contents(atPath: logURL.path),
           let text = String(data: data, encoding: .utf8) {
            existingContent = text + "\n"
        }

        let newEntry = existingContent + crashInfo.description + "\n"
        try newEntry.write(to: logURL, atomically: true, encoding: .utf8)

        print("📄  Crash log written to: \(logURL.path)")
        return logURL
    }

    /// Read and return the contents of `crashlog.txt` (returns `nil` if not found).
    public func readCrashLog() -> String? {
        let logURL = outputDirectory.appendingPathComponent("crashlog.txt")
        guard FileManager.default.fileExists(atPath: logURL.path),
              let data = FileManager.default.contents(atPath: logURL.path),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text
    }

    /// Parse every crash entry from `crashlog.txt` and return them as an array of strings.
    public func parsedEntries() -> [String] {
        guard let content = readCrashLog() else { return [] }
        let separator = "=== iOS Project Template Crash Report ==="
        let parts = content.components(separatedBy: separator)
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { separator + "\n" + $0 }
    }

    // MARK: - Simulated crash log

    /// Produce a `CrashInfo` that simulates a forced-unwrap crash for demonstration.
    public static func simulatedCrashInfo() -> CrashInfo {
        CrashInfo(
            timestamp: Date(),
            signal: SIGABRT,
            signalName: "SIGABRT",
            reason: "Fatal error: Unexpectedly found nil while unwrapping an Optional value",
            threadInfo: "Thread 0 (main) — force-unwrap at main.swift:42",
            appVersion: "1.0.0"
        )
    }
}
