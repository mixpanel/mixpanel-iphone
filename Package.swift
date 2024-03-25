// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Mixpanel",
    platforms: [
      .iOS(.v12),
      .tvOS(.v12),
      .macOS(.v10_13),
      .watchOS(.v4),
    ],
    products: [
        .library(name: "Mixpanel", targets: ["Mixpanel"]),
    ],
    targets: [
        .target(
            name: "Mixpanel",
            path: "Sources",
            resources: [
                .copy("Mixpanel/PrivacyInfo.xcprivacy")
            ],
            cSettings: [
                .headerSearchPath("."),
            ]
        ),
    ]
)
