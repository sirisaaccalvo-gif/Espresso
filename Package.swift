// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Espresso",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure, framework-light logic — depended on by the app and the test runner.
        .target(
            name: "EspressoKit",
            path: "Sources/EspressoKit",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
        // The menu-bar app.
        .executableTarget(
            name: "Espresso",
            dependencies: ["EspressoKit"],
            path: "Sources/Espresso",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        // Dependency-free test runner (XCTest/Testing need full Xcode). Run: swift run EspressoTests
        .executableTarget(
            name: "EspressoTests",
            dependencies: ["EspressoKit"],
            path: "Tests/EspressoTests",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
