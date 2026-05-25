// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WidflyKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WidflyKit", targets: ["WidflyKit"]),
        .executable(name: "widfly-scraper", targets: ["widfly-scraper"]),
    ],
    targets: [
        .target(name: "WidflyKit"),
        .executableTarget(
            name: "widfly-scraper",
            dependencies: ["WidflyKit"],
            linkerSettings: [
                .linkedFramework("WebKit", .when(platforms: [.macOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
    ]
)
