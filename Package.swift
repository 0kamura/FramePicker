// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FramePicker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FramePicker", targets: ["FramePicker"])
    ],
    targets: [
        .target(name: "FramePickerCore"),
        .executableTarget(
            name: "FramePicker",
            dependencies: ["FramePickerCore"]
        ),
        .testTarget(
            name: "FramePickerCoreTests",
            dependencies: ["FramePickerCore"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
