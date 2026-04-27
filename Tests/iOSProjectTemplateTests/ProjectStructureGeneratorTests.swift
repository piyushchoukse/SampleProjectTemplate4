import XCTest
@testable import iOSProjectTemplate

final class ProjectStructureGeneratorTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iOSTemplateTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - ProjectStructureGenerator

    func testGeneratorCreatesRootDirectory() throws {
        let generator = ProjectStructureGenerator(
            projectName: "TestApp",
            modules: [],
            outputDirectory: tempDir
        )
        try generator.generate()

        let rootURL = tempDir.appendingPathComponent("TestApp")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: rootURL.path),
            "Root project directory should be created"
        )
    }

    func testGeneratorCreatesCoreFolders() throws {
        let generator = ProjectStructureGenerator(
            projectName: "CoreApp",
            modules: [],
            outputDirectory: tempDir
        )
        let created = try generator.generate()

        let expectedFolders = [
            "CoreApp",
            "CoreApp/Application",
            "CoreApp/Models",
            "CoreApp/Views",
            "CoreApp/Controllers",
            "CoreApp/Services",
            "CoreApp/Utilities",
            "CoreApp/Resources/Assets.xcassets",
            "CoreApp/Resources/Storyboards",
            "CoreApp/SupportingFiles",
            "CoreAppTests",
            "CoreAppUITests"
        ]

        for folder in expectedFolders {
            XCTAssertTrue(
                created.contains(folder),
                "Expected '\(folder)' to be in the created paths"
            )
            let url = tempDir.appendingPathComponent(folder)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "Directory '\(folder)' should exist on disk"
            )
        }
    }

    func testGeneratorCreatesAppDelegateStub() throws {
        let generator = ProjectStructureGenerator(
            projectName: "StubApp",
            modules: [],
            outputDirectory: tempDir
        )
        try generator.generate()

        let appDelegateURL = tempDir
            .appendingPathComponent("StubApp/Application/AppDelegate.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: appDelegateURL.path),
            "AppDelegate.swift stub should be created"
        )
        let content = try String(contentsOf: appDelegateURL, encoding: .utf8)
        XCTAssertTrue(content.contains("UIApplicationDelegate"))
    }

    func testGeneratorCreatesSceneDelegateStub() throws {
        let generator = ProjectStructureGenerator(
            projectName: "StubApp",
            modules: [],
            outputDirectory: tempDir
        )
        try generator.generate()

        let url = tempDir.appendingPathComponent("StubApp/Application/SceneDelegate.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("UIWindowSceneDelegate"))
    }

    func testGeneratorCreatesInfoPlist() throws {
        let generator = ProjectStructureGenerator(
            projectName: "PlistApp",
            modules: [],
            outputDirectory: tempDir
        )
        try generator.generate()

        let url = tempDir.appendingPathComponent("PlistApp/SupportingFiles/Info.plist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("PlistApp"))
    }

    func testGeneratorCreatesModuleDirectories() throws {
        let modules: [ProjectModule] = [.networking, .persistence]
        let generator = ProjectStructureGenerator(
            projectName: "ModuleApp",
            modules: modules,
            outputDirectory: tempDir
        )
        let created = try generator.generate()

        XCTAssertTrue(created.contains("ModuleApp/Networking"))
        XCTAssertTrue(created.contains("ModuleApp/Persistence"))

        let netDir = tempDir.appendingPathComponent("ModuleApp/Networking")
        XCTAssertTrue(FileManager.default.fileExists(atPath: netDir.path))
    }

    func testGeneratorCreatesModuleManagerFiles() throws {
        let generator = ProjectStructureGenerator(
            projectName: "ManagerApp",
            modules: [.analytics],
            outputDirectory: tempDir
        )
        let created = try generator.generate()

        XCTAssertTrue(
            created.contains("ManagerApp/Analytics/AnalyticsManager.swift")
        )
        let url = tempDir.appendingPathComponent(
            "ManagerApp/Analytics/AnalyticsManager.swift"
        )
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("AnalyticsManager"))
        XCTAssertTrue(content.contains("shared"))
    }

    func testAllModulesAreGenerated() throws {
        let generator = ProjectStructureGenerator(
            projectName: "AllModulesApp",
            modules: ProjectModule.allCases,
            outputDirectory: tempDir
        )
        let created = try generator.generate()

        for module in ProjectModule.allCases {
            let expectedPath = "AllModulesApp/\(module.rawValue)"
            XCTAssertTrue(created.contains(expectedPath))
        }
    }

    // MARK: - CrashLogReader

    func testCrashLogReaderWritesFile() throws {
        let reader = CrashLogReader(outputDirectory: tempDir)
        let crash = CrashLogReader.simulatedCrashInfo()
        let url = try reader.writeCrashLog(crash)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.lastPathComponent, "crashlog.txt")
    }

    func testCrashLogReaderContainsCrashReason() throws {
        let reader = CrashLogReader(outputDirectory: tempDir)
        let crash = CrashLogReader.simulatedCrashInfo()
        try reader.writeCrashLog(crash)

        let content = reader.readCrashLog()
        XCTAssertNotNil(content)
        XCTAssertTrue(content!.contains("nil"))
        XCTAssertTrue(content!.contains("SIGABRT"))
    }

    func testCrashLogReaderAppendsEntries() throws {
        let reader = CrashLogReader(outputDirectory: tempDir)

        let crash1 = CrashLogReader.simulatedCrashInfo()
        let crash2 = CrashLogReader.simulatedCrashInfo()
        try reader.writeCrashLog(crash1)
        try reader.writeCrashLog(crash2)

        let entries = reader.parsedEntries()
        XCTAssertEqual(entries.count, 2, "Two crash entries should be present")
    }

    func testReadCrashLogReturnsNilWhenMissing() {
        let nonExistent = tempDir.appendingPathComponent("nonexistent")
        let reader = CrashLogReader(outputDirectory: nonExistent)
        XCTAssertNil(reader.readCrashLog())
    }

    // MARK: - MCPConnectAgent (dry-run)

    func testDryRunCreatesBugResultWithProjectKey() throws {
        let config = MCPConnectAgent.Configuration(
            serverURL: URL(string: "https://mcp.example.com")!,
            authToken: "test-token",
            jiraProjectKey: "TST"
        )
        let agent = MCPConnectAgent(configuration: config)
        let crash = CrashLogReader.simulatedCrashInfo()
        let result = agent.dryRunCreateJiraBug(from: crash)

        XCTAssertTrue(result.issueKey.hasPrefix("TST-"))
        XCTAssertTrue(result.issueURL.contains("TST-"))
        XCTAssertFalse(result.summary.isEmpty)
    }

    func testDryRunSummaryContainsSignalName() {
        let config = MCPConnectAgent.Configuration(
            serverURL: URL(string: "https://mcp.example.com")!,
            authToken: "test-token",
            jiraProjectKey: "IOS"
        )
        let agent = MCPConnectAgent(configuration: config)
        let crash = CrashLogReader.simulatedCrashInfo()
        let result = agent.dryRunCreateJiraBug(from: crash)

        XCTAssertTrue(result.summary.contains("SIGABRT"))
    }

    // MARK: - CrashInfo

    func testCrashInfoDescriptionContainsAllFields() {
        let crash = CrashInfo(
            timestamp: Date(),
            signal: SIGABRT,
            signalName: "SIGABRT",
            reason: "nil unwrap",
            threadInfo: "Thread 0",
            appVersion: "2.1.0"
        )
        let desc = crash.description
        XCTAssertTrue(desc.contains("SIGABRT"))
        XCTAssertTrue(desc.contains("nil unwrap"))
        XCTAssertTrue(desc.contains("Thread 0"))
        XCTAssertTrue(desc.contains("2.1.0"))
    }
}
