// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "iOSProjectTemplate",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "iOSProjectTemplate",
            path: "Sources/iOSProjectTemplate"
        ),
        .testTarget(
            name: "iOSProjectTemplateTests",
            dependencies: ["iOSProjectTemplate"],
            path: "Tests/iOSProjectTemplateTests"
        )
    ]
)
