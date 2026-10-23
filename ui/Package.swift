// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DailyLoggerUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DailyLoggerUI", targets: ["DailyLoggerUI"])
    ],
    targets: [
        .executableTarget(
            name: "DailyLoggerUI",
            path: "Sources/DailyLogger"
        )
    ]
)
