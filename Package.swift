// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VideoCutter",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VideoCutter", targets: ["VideoCutter"])
    ],
    targets: [
        .executableTarget(
            name: "VideoCutter",
            path: ".",
            exclude: [".codex", ".gitignore", "README.md", "dist", "script", "tmp"]
        )
    ]
)
