// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VimeoDownloader",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "VimeoDownloader",
            targets: ["VimeoDownloader"]
        )
    ],
    targets: [
        .executableTarget(
            name: "VimeoDownloader",
            path: "Sources/VimeoDownloader"
        )
    ]
)
