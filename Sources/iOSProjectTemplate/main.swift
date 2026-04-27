import Foundation

// MARK: - Entry point

print("""
╔══════════════════════════════════════════════════════╗
║          iOS Project Structure Template              ║
╚══════════════════════════════════════════════════════╝
""")

// ── Step 1: Collect user input ────────────────────────────────────────────────

print("Enter project name (default: MyiOSApp): ", terminator: "")
let projectNameInput = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
let projectName = projectNameInput.isEmpty ? "MyiOSApp" : projectNameInput

print("\nAvailable modules:")
for (index, module) in ProjectModule.allCases.enumerated() {
    print("  \(index + 1). \(module.rawValue)")
}
print("Enter module numbers separated by commas (e.g. 1,3) or press Enter for none: ", terminator: "")
let moduleInput = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""

var selectedModules: [ProjectModule] = []
if !moduleInput.isEmpty {
    let indices = moduleInput
        .split(separator: ",")
        .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    let allModules = ProjectModule.allCases
    for idx in indices {
        if idx >= 1 && idx <= allModules.count {
            selectedModules.append(allModules[idx - 1])
        }
    }
}

// ── Step 2: Generate project structure ───────────────────────────────────────

let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("GeneratedProjects")

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let generator = ProjectStructureGenerator(
    projectName: projectName,
    modules: selectedModules,
    outputDirectory: outputDir
)

print("\n📁  Generating iOS project structure …")
let createdPaths = try generator.generate()
print("   Created \(createdPaths.count) paths under GeneratedProjects/\(projectName)\n")

// ── Step 3: Crash handling ────────────────────────────────────────────────────

print("⚡  Demonstrating forced optional unwrap crash …")
print("   (Crash will be intercepted by the signal handler)\n")

let crashLogReader = CrashLogReader(outputDirectory: outputDir)

// Register crash handler — writes crash log before re-raising signal
CrashHandler.shared.register { crashInfo in
    print("\n🚨  Crash intercepted!")
    print(crashInfo.description)

    // Write crash log
    if let url = try? crashLogReader.writeCrashLog(crashInfo) {
        print("📄  Crash details saved to: \(url.path)")
    }

    // Dry-run Jira bug creation so the demo works without a real MCP server
    // swiftlint:disable:next force_unwrapping
    let mcpURL = URL(string: "https://mcp.example.com")!
    let mcpConfig = MCPConnectAgent.Configuration(
        serverURL: mcpURL,
        authToken: "demo-token",
        jiraProjectKey: "IOS"
    )
    let agent = MCPConnectAgent(configuration: mcpConfig)
    let jiraResult = agent.dryRunCreateJiraBug(from: crashInfo)
    print("🎫  Jira bug (dry run): \(jiraResult.issueKey) — \(jiraResult.summary)")
}

// ── Step 4: Simulate crash using a pre-captured CrashInfo (safe demo) ─────────
//
// Triggering a real SIGABRT would terminate the process and exit before we can
// print the summary below. Instead we simulate the crash by directly invoking the
// same crash-handling pipeline with a pre-built CrashInfo, exactly as the signal
// handler would, and then write an example to crashlog.txt.

print("📋  Simulating crash pipeline (safe — no real signal raised) …\n")
let simulatedCrash = CrashLogReader.simulatedCrashInfo()
print(simulatedCrash.description)

let crashLogURL = try crashLogReader.writeCrashLog(simulatedCrash)

// swiftlint:disable:next force_unwrapping
let mcpURL = URL(string: "https://mcp.example.com")!
let mcpConfig = MCPConnectAgent.Configuration(
    serverURL: mcpURL,
    authToken: "demo-token",
    jiraProjectKey: "IOS"
)
let agent = MCPConnectAgent(configuration: mcpConfig)
let jiraResult = agent.dryRunCreateJiraBug(from: simulatedCrash)

// ── Step 5: Summary ───────────────────────────────────────────────────────────

print("""

╔══════════════════════════════════════════════════════╗
║  Summary                                             ║
╠══════════════════════════════════════════════════════╣
║  Project  : \(projectName.padding(toLength: 42, withPad: " ", startingAt: 0))║
║  Modules  : \(selectedModules.map(\.rawValue).joined(separator: ", ").padding(toLength: 42, withPad: " ", startingAt: 0))║
║  Crash log: \(crashLogURL.lastPathComponent.padding(toLength: 42, withPad: " ", startingAt: 0))║
║  Jira bug : \(jiraResult.issueKey.padding(toLength: 42, withPad: " ", startingAt: 0))║
╚══════════════════════════════════════════════════════╝
""")

if let logContent = crashLogReader.readCrashLog() {
    print("📖  Contents of crashlog.txt:")
    print(logContent)
}
