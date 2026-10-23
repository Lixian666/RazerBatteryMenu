// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "RazerBatteryMenu",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "RazerBatteryMenu", targets: ["RazerBatteryMenu"]),
    .executable(name: "RazerDiagnostics", targets: ["RazerDiagnostics"]),
  ],
  targets: [
    .target(name: "RazerCore"),
    .target(
      name: "RazerHID",
      dependencies: ["RazerCore"],
      linkerSettings: [.linkedFramework("IOKit")]
    ),
    .executableTarget(
      name: "RazerBatteryMenu",
      dependencies: ["RazerCore", "RazerHID"]
    ),
    .executableTarget(
      name: "RazerDiagnostics",
      dependencies: ["RazerCore", "RazerHID"]
    ),
    .executableTarget(
      name: "RazerCoreChecks",
      dependencies: ["RazerCore"],
      path: "Tests/RazerCoreTests"
    ),
  ]
)
