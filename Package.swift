//
//  Package.swift
//  NotificationServer
//
//  Created by Uğurcan Polat on 1.07.2017.
//
//

import PackageDescription

let package = Package(
    name: "NotificationServer",
    targets: [],
    dependencies: [
        Package.Dependency.Package(url: "https://github.com/PerfectlySoft/Perfect-HTTP.git", majorVersion: 2),
        Package.Dependency.Package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", majorVersion: 2),
        Package.Dependency.Package(url: "https://github.com/PerfectlySoft/Perfect-Notifications.git", majorVersion: 2),
        Package.Dependency.Package(url:"https://github.com/PerfectlySoft/Perfect-MySQL.git", majorVersion: 2)
    ]
)
