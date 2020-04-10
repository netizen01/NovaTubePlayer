// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NovaTubePlayer",
    products: [
        .library(name: "NovaTubePlayer", targets: ["NovaTubePlayer"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "NovaTubePlayer", dependencies: [])
    ]
)
