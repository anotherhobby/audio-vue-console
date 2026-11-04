// swift-tools-version: 6.2
import PackageDescription

/// The app's logic, kept free of any UI framework so another platform's UI can sit on it.
let package = Package(
    name: "ConsoleCore",
    platforms: [.macOS("27.2")],
    products: [.library(name: "ConsoleCore", targets: ["ConsoleCore"])],
    targets: [
        .target(name: "ConsoleCore", swiftSettings: [.treatAllWarnings(as: .error)]),
        .testTarget(
            name: "ConsoleCoreTests", dependencies: ["ConsoleCore"],
            swiftSettings: [.treatAllWarnings(as: .error)]),
    ],
    swiftLanguageModes: [.v6]
)
