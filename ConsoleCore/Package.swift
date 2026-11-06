// swift-tools-version: 6.2
import PackageDescription

/// The app's logic, kept free of any UI framework so another platform's UI can sit on it. `HostAPI`
/// holds the host's saved contract and the client generated from it, at `package` access, so only
/// `ConsoleCore` reaches it.
let package = Package(
    name: "ConsoleCore",
    platforms: [.macOS("27.2")],
    products: [.library(name: "ConsoleCore", targets: ["ConsoleCore"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "1.14.4"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", exact: "1.13.4"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", exact: "1.4.0"),
        .package(url: "https://github.com/apple/swift-http-types", exact: "1.8.0"),
    ],
    targets: [
        .target(
            name: "HostAPI",
            dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")],
            resources: [.copy("openapi.json")],
            // The generated code says each import's level; SwiftPM's resource accessor does not, and
            // the two are ambiguous unless a plain import is internal (SE-0409, design D1).
            swiftSettings: [
                .treatAllWarnings(as: .error), .enableUpcomingFeature("InternalImportsByDefault"),
            ],
            plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]),
        .target(
            name: "ConsoleCore",
            dependencies: [
                "HostAPI",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            swiftSettings: [.treatAllWarnings(as: .error)]),
        .testTarget(
            name: "ConsoleCoreTests",
            dependencies: [
                "ConsoleCore",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
            ],
            swiftSettings: [.treatAllWarnings(as: .error)]),
    ],
    swiftLanguageModes: [.v6]
)
