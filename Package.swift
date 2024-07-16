// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mp3HlsStreaming",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "Mp3HlsStreaming",
            targets: ["RemoteStreamerPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", branch: "main")
    ],
    targets: [
        .target(
            name: "RemoteStreamerPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/RemoteStreamerPlugin"),
        .testTarget(
            name: "RemoteStreamerPluginTests",
            dependencies: ["RemoteStreamerPlugin"],
            path: "ios/Tests/RemoteStreamerPluginTests")
    ]
)