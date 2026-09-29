// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NotchNull",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NotchNull",
            path: "Sources/NotchNull",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("IOKit"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("EventKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Network"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreWLAN"),
            ]
        ),
        .testTarget(
            name: "NotchNullTests",
            dependencies: ["NotchNull"],
            path: "Tests/NotchNullTests"
        ),
    ]
)
