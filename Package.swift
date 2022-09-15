// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EventKitUtils",
    defaultLocalization: "en",
    platforms: [.iOS(.v14), .macOS(.v11), .macCatalyst(.v14)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "EventKitUtils",
            targets: ["EventKitUtils"]),
        .library(name: "EventKitUtilsUI",
                 targets: ["EventKitUtilsUI"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/grepug/UIKitUtils", branch: "dev_3.3.7"),
        .package(
           url: "https://github.com/apple/swift-collections.git",
           .upToNextMajor(from: "1.0.0") // or `.upToNextMinor
         ),
        .package(url: "https://github.com/scalessec/Toast-Swift.git", branch: "master")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "EventKitUtils",
            dependencies: [.product(name: "Collections", package: "swift-collections")],
            path: "Sources/EventKitUtils"),
        .target(name: "EventKitUtilsUI",
                dependencies: ["EventKitUtils",
                               .product(name: "TextEditorCellConfiguration", package: "UIKitUtils"),
                               .product(name: "Toast", package: "Toast-Swift")],
                path: "Sources/EventKitUtilsUI"),
        .testTarget(
            name: "EventKitUtilsTests",
            dependencies: ["EventKitUtils", "EventKitUtilsUI", "UIKitUtils"]),
    ]
)
