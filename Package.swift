// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NotimeToEat",
    defaultLocalization: "zh",
    platforms: [
        .iOS(.v15) // iOS 15及以上，代码中会要求iOS 17
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
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.17.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "7.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package
        .target(
            name: "NotimeToEat",
            dependencies: [
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
            ],
            path: "NotimeToEat",
            swiftSettings: [
                .define("iOS_ONLY"), 
                .define("SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG iOS")
            ]),
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