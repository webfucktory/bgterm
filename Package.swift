// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "bgterm",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .target(name: "BgtermCore"),
        .executableTarget(
            name: "bgterm",
            dependencies: [
                "BgtermCore",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]
        ),
        .testTarget(name: "BgtermCoreTests", dependencies: ["BgtermCore"]),
        .testTarget(
            name: "bgtermTests",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]
        )
    ]
)
