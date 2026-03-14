// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SleepAnalyser",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SleepAnalyser", targets: ["SleepAnalyser"])
    ],
    targets: [
        .executableTarget(
            name: "SleepAnalyser",
            path: "SleepAnalyser",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SleepAnalyserTests",
            dependencies: ["SleepAnalyser"],
            path: "SleepAnalyserTests"
        ),
    ]
)
