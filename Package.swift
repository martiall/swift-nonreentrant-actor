// swift-tools-version: 6.0
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "NonReentrant",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "test",
            dependencies: [
                .target(name: "NonReentrant"),
            ]
        ),
        .target(
            name: "NonReentrant",
            dependencies: [
                .target(name: "NonReentrantMacros"),
            ]
        ),
        .macro(
            name: "NonReentrantMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "NonRentrantMacrosTests",
            dependencies: [
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .target(name: "NonReentrantMacros")
            ]
        ),
    ]
)
