// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacFolderView",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "MacFolderView",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "MacFolderView"
        )
    ]
)
