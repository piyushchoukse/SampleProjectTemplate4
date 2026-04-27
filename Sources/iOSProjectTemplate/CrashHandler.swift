import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// MARK: - CrashInfo

/// Holds information captured during a crash.
public struct CrashInfo {
    public let timestamp: Date
    public let signal: Int32
    public let signalName: String
    public let reason: String
    public let threadInfo: String
    public let appVersion: String

    public var description: String {
        let formatter = ISO8601DateFormatter()
        return """
        === iOS Project Template Crash Report ===
        Date:        \(formatter.string(from: timestamp))
        AppVersion:  \(appVersion)
        Signal:      \(signalName) (\(signal))
        Reason:      \(reason)
        Thread:      \(threadInfo)
        ==========================================
        """
    }
}

// MARK: - CrashHandler

/// Installs UNIX signal handlers and surfaces crash information for logging.
public final class CrashHandler {

    // Shared singleton for use inside C signal handlers
    nonisolated(unsafe) public static let shared = CrashHandler()

    private var onCrash: ((CrashInfo) -> Void)?
    nonisolated(unsafe) private static var capturedInfo: CrashInfo?

    private init() {}

    // MARK: - Public API

    /// Register a callback that is invoked synchronously inside the signal handler.
    /// Keep the callback **async-signal-safe** (write to a pipe, set a flag, etc.).
    public func register(onCrash: @escaping (CrashInfo) -> Void) {
        self.onCrash = onCrash
        installHandlers()
    }

    /// Trigger a **forceful crash** by force-unwrapping a `nil` Optional.
    /// This is intentional to demonstrate crash capture behaviour.
    public func triggerForcedCrash() {
        print("⚠️  Triggering forced crash by unwrapping nil Optional …")
        let nilValue: String? = nil
        // Force-unwrap a nil Optional → produces a fatal error (EXC_BAD_INSTRUCTION / SIGABRT)
        _ = nilValue!   // swiftlint:disable:this force_unwrapping
    }

    // MARK: - Private

    private func installHandlers() {
        let signals: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP]
        for sig in signals {
            // Signal handlers must be literal closures (C function pointers)
            signal(sig) { receivedSig in
                let info = CrashInfo(
                    timestamp: Date(),
                    signal: receivedSig,
                    signalName: CrashHandler.signalName(for: receivedSig),
                    reason: "Fatal error: Unexpectedly found nil while unwrapping an Optional value",
                    threadInfo: "Thread 0 (main)",
                    appVersion: "1.0.0"
                )
                CrashHandler.capturedInfo = info
                CrashHandler.shared.onCrash?(info)

                // Re-raise so the OS records the crash normally
                signal(receivedSig, SIG_DFL)
                raise(receivedSig)
            }
        }
    }

    private static func signalName(for sig: Int32) -> String {
        switch sig {
        case SIGABRT: return "SIGABRT"
        case SIGILL:  return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE:  return "SIGFPE"
        case SIGBUS:  return "SIGBUS"
        case SIGTRAP: return "SIGTRAP"
        default:      return "SIG(\(sig))"
        }
    }
}
