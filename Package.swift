// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Mixpanel",
    platforms: [
      .iOS(.v9),
      .tvOS(.v9),
      .macOS(.v10_10),
      .watchOS(.v3),
    ],
    products: [
        .library(name: "Mixpanel", targets: ["Mixpanel"]),
    ],
    targets: [
        .target(
            name: "Mixpanel",
            path: "Sources",
            cSettings: [
                .headerSearchPath("."),
            ]
        ),
    ]
)
