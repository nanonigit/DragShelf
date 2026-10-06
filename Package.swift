// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DragShelf",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DragShelf", targets: ["DragShelf"]),
        .executable(name: "DragShelfLoginItem", targets: ["DragShelfLoginItem"]),
        .library(name: "DragShelfCore", targets: ["DragShelfCore"]),
    ],
    targets: [
        .target(name: "DragShelfCore"),
        .executableTarget(name: "DragShelf", dependencies: ["DragShelfCore"]),
        .executableTarget(name: "DragShelfLoginItem"),
        .testTarget(name: "DragShelfCoreTests", dependencies: ["DragShelfCore"]),
        .testTarget(name: "DragShelfAppTests", dependencies: ["DragShelf", "DragShelfCore"]),
    ]
)
