// swift-tools-version: 6.0
// Package.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import PackageDescription

let package = Package(
    name: "dewdiary",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0" ..< "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "dewdiary",
            dependencies: [.product(name: "Crypto", package: "swift-crypto")]
        ),
    ]
)
