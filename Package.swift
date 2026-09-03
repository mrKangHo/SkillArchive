// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SkillArchive",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SkillArchive",
            path: "Sources/SkillArchive",
            resources: [
                .process("Localizable.xcstrings")
            ]
        )
    ]
)
