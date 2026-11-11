// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MDPeek",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1")
    ],
    targets: [
        .executableTarget(name: "MDPeek", dependencies: [.product(name: "MarkdownUI", package: "swift-markdown-ui")])
    ]
)
