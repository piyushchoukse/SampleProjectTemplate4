import Foundation

/// Represents a module/feature that can be included in the generated iOS project.
public enum ProjectModule: String, CaseIterable {
    case networking  = "Networking"
    case persistence = "Persistence"
    case analytics   = "Analytics"
    case authentication = "Authentication"
    case notifications  = "Notifications"
    case localization   = "Localization"
}

/// Generates a standard iOS project folder structure on disk.
public struct ProjectStructureGenerator {

    public let projectName: String
    public let modules: [ProjectModule]
    public let outputDirectory: URL

    public init(projectName: String, modules: [ProjectModule], outputDirectory: URL) {
        self.projectName = projectName
        self.modules = modules
        self.outputDirectory = outputDirectory
    }

    // MARK: - Public API

    /// Creates all directories and stub files for the project.
    /// Returns the list of created paths relative to `outputDirectory`.
    @discardableResult
    public func generate() throws -> [String] {
        let root = outputDirectory.appendingPathComponent(projectName)
        var created: [String] = []

        // Core iOS application directories
        let corePaths: [String] = [
            projectName,                               // root
            "\(projectName)/Application",
            "\(projectName)/Models",
            "\(projectName)/Views",
            "\(projectName)/Controllers",
            "\(projectName)/Services",
            "\(projectName)/Utilities",
            "\(projectName)/Resources/Assets.xcassets",
            "\(projectName)/Resources/Storyboards",
            "\(projectName)/SupportingFiles",
            "\(projectName)Tests",
            "\(projectName)UITests"
        ]

        for relativePath in corePaths {
            let dir = outputDirectory.appendingPathComponent(relativePath)
            try createDirectory(at: dir)
            created.append(relativePath)
        }

        // Stub Swift files in Application layer
        let appStubs: [(name: String, content: String)] = [
            (
                "\(projectName)/Application/AppDelegate.swift",
                appDelegateStub()
            ),
            (
                "\(projectName)/Application/SceneDelegate.swift",
                sceneDelegateStub()
            ),
            (
                "\(projectName)/SupportingFiles/Info.plist",
                infoPlistStub()
            )
        ]

        for stub in appStubs {
            let fileURL = outputDirectory.appendingPathComponent(stub.name)
            try writeFile(content: stub.content, to: fileURL)
            created.append(stub.name)
        }

        // Optional module directories
        for module in modules {
            let modulePath = "\(projectName)/\(module.rawValue)"
            let dir = outputDirectory.appendingPathComponent(modulePath)
            try createDirectory(at: dir)
            created.append(modulePath)

            let stubURL = dir.appendingPathComponent("\(module.rawValue)Manager.swift")
            try writeFile(content: moduleManagerStub(module: module), to: stubURL)
            created.append("\(modulePath)/\(module.rawValue)Manager.swift")
        }

        print("✅  Project '\(projectName)' created at: \(root.path)")
        print("   Directories and files created: \(created.count)")
        return created
    }

    // MARK: - Private helpers

    private func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func writeFile(content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Stub content

    private func appDelegateStub() -> String {
        """
        import UIKit

        @main
        class AppDelegate: UIResponder, UIApplicationDelegate {

            func application(
                _ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
            ) -> Bool {
                return true
            }
        }
        """
    }

    private func sceneDelegateStub() -> String {
        """
        import UIKit

        class SceneDelegate: UIResponder, UIWindowSceneDelegate {

            var window: UIWindow?

            func scene(
                _ scene: UIScene,
                willConnectTo session: UISceneSession,
                options connectionOptions: UIScene.ConnectionOptions
            ) {
                guard let _ = (scene as? UIWindowScene) else { return }
            }
        }
        """
    }

    private func infoPlistStub() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
            "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleName</key>
            <string>\(projectName)</string>
            <key>CFBundleIdentifier</key>
            <string>com.example.\(projectName.lowercased())</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0</string>
            <key>UIMainStoryboardFile</key>
            <string>Main</string>
            <key>UILaunchStoryboardName</key>
            <string>LaunchScreen</string>
        </dict>
        </plist>
        """
    }

    private func moduleManagerStub(module: ProjectModule) -> String {
        """
        import Foundation

        /// Manager for the \(module.rawValue) module.
        public class \(module.rawValue)Manager {

            public static let shared = \(module.rawValue)Manager()

            private init() {}

            public func configure() {
                // TODO: Configure \(module.rawValue)
            }
        }
        """
    }
}
