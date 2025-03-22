// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NotimeToEat",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces
        .library(
            name: "NotimeToEat",
            targets: ["NotimeToEat"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package
        .target(
            name: "NotimeToEat",
            dependencies: [],
            path: "NotimeToEat"),
        .testTarget(
            name: "NotimeToEatTests",
            dependencies: ["NotimeToEat"],
            path: "NotimeToEatTests"),
        .testTarget(
            name: "NotimeToEatUITests",
            dependencies: ["NotimeToEat"],
            path: "NotimeToEatUITests"),
    ]
) 