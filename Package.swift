// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HDShare",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "HDShare", targets: ["HDShare"])
    ],
    targets: [
        .executableTarget(
            name: "HDShare",
            path: "Sources/HDShare"
        ),
    ]
)
