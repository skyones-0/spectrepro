// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-vt-xcframework",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "swift-vt-xcframework",
            dependencies: ["SpectreProVt"],
            path: "Sources"
        ),
        .binaryTarget(
            name: "SpectreProVt",
            path: "../../zig-out/lib/spectrepro-vt.xcframework"
        ),
    ]
)
