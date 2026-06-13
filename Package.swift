// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "tasb",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .target(name: "TasbCore"),
        .executableTarget(
            name: "tasb",
            dependencies: [
                "TasbCore",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]
        ),
        .testTarget(name: "TasbCoreTests", dependencies: ["TasbCore"]),
        .testTarget(
            name: "tasbTests",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]
        )
    ]
)
