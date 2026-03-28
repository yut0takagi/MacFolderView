// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacFolderView",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacFolderView",
            path: "MacFolderView"
        )
    ]
)
