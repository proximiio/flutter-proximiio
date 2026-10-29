// swift-tools-version: 5.9

import PackageDescription

// The Proximi.io SDK version is pinned exactly: each flutter_proximiio release is
// built and tested against one native SDK release. Keep it equal to the version in
// ../flutter_proximiio.podspec.
let package = Package(
    name: "flutter_proximiio",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "flutter-proximiio", targets: ["flutter_proximiio"])
    ],
    dependencies: [
        .package(url: "https://github.com/proximiio/proximiio-sdk-ios-binary.git", exact: "6.0.0-beta.67")
    ],
    targets: [
        .target(
            name: "flutter_proximiio",
            dependencies: [
                .product(name: "Proximiio", package: "proximiio-sdk-ios-binary")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
