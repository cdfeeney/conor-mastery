// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MasteryCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "MasteryCore", targets: ["MasteryCore"])
    ],
    targets: [
        .target(name: "MasteryCore"),
        .testTarget(name: "MasteryCoreTests", dependencies: ["MasteryCore"])
    ]
)
