// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "first-light",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "Apple1Core", targets: ["Apple1Core"]),
        .executable(name: "FirstLight", targets: ["FirstLight"]),
    ],
    targets: [
        // Mike Chambers' fake6502 (public domain), unmodified except for
        // disabling the NES_CPU define so BCD arithmetic works.
        .target(name: "CFake6502"),

        // The Apple-1 machine: memory map, PIA 6820, terminal section, ROMs.
        // Pure model code — no UI dependencies, portable to iPad/visionOS.
        .target(
            name: "Apple1Core",
            dependencies: ["CFake6502"],
            resources: [.copy("Resources/ROMs")]
        ),

        .executableTarget(
            name: "FirstLight",
            dependencies: ["Apple1Core"],
            resources: [.copy("Resources")]
        ),

        .testTarget(
            name: "Apple1CoreTests",
            dependencies: ["Apple1Core"]
        ),
    ]
)
