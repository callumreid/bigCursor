// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "bigCursor",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "bigCursor",
            path: "Sources"
        )
    ]
)

