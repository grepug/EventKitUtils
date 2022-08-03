// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EventKitUtils",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "EventKitUtils",
            targets: ["EventKitUtils"]),
    ],
    dependencies: [
        .package(url: "https://github.com/grepug/DiffableList", branch: "dev_3.1.0"),
        .package(url: "https://github.com/grepug/MenuBuilder", branch: "master"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", .upToNextMajor(from: "5.0.1")),
        .package(
           url: "https://github.com/apple/swift-collections.git",
           .upToNextMajor(from: "1.0.0") // or `.upToNextMinor
         )
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "EventKitUtils",
            dependencies: ["DiffableList",
                           "MenuBuilder",
                           "SnapKit",
                           .product(name: "Collections",
                                    package: "swift-collections")]),
        .testTarget(
            name: "EventKitUtilsTests",
            dependencies: ["EventKitUtils"]),
    ]
)
