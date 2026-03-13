<div align="center">
  <img src="Images/logo.png" alt="Tiercel logo" width="600"/>
</div>

<p align="center">
  <a href="README.md"><strong>English</strong></a> |
  <a href="README.zh.md"><strong>简体中文</strong></a>
</p>

<p align="center">
  <a href="https://cocoapods.org/pods/Tiercel"><img src="https://img.shields.io/cocoapods/v/Tiercel.svg?style=flat" alt="CocoaPods Version" /></a>
  <a href="https://cocoapods.org/pods/Tiercel"><img src="https://img.shields.io/cocoapods/p/Tiercel.svg?style=flat" alt="Platform" /></a>
  <a href="https://swift.org/package-manager/"><img src="https://img.shields.io/badge/SwiftPM-supported-FA7343.svg?style=flat" alt="Swift Package Manager" /></a>
  <a href="https://www.swift.org/"><img src="https://img.shields.io/badge/Swift-5.0%2B-F05138.svg?style=flat" alt="Swift" /></a>
  <a href="https://developer.apple.com/ios/"><img src="https://img.shields.io/badge/iOS-12.0%2B-0A84FF.svg?style=flat" alt="iOS 12.0+" /></a>
  <a href="https://github.com/Danie1s/Tiercel/commits/master"><img src="https://img.shields.io/github/last-commit/Danie1s/Tiercel/master?style=flat" alt="Last Commit" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/cocoapods/l/Tiercel.svg?style=flat" alt="License" /></a>
</p>

Tiercel is a pure-Swift download framework for iOS with native-style background downloads, resumable transfers, and fine-grained task management. It is built for apps that need more than a single fire-and-forget request: batch operations, isolated download managers, persistence across relaunches, validation hooks, and production-friendly progress reporting.

If you are working in Objective-C, use [TiercelObjCBridge](https://github.com/Danie1s/TiercelObjCBridge).
For responsible vulnerability disclosure, see [SECURITY.md](SECURITY.md).
If you want to contribute, start with [CONTRIBUTING.md](CONTRIBUTING.md).

## Why Tiercel

- Native-style background downloads built on top of `URLSession`.
- Resume support after relaunch through persisted task metadata and resume data.
- Per-task and manager-level controls for start, suspend, cancel, remove, and batch operations.
- Multiple `SessionManager` instances so different download domains can stay isolated.
- Configurable concurrency and network access policy, including cellular, constrained, and expensive networks.
- Built-in speed, remaining time, and file validation callbacks.
- Thread-safe internal state designed for long-running, real-world download flows.

## Project Status

Tiercel continues to be maintained on the 3.2.x line. Recent work in this repository focuses on thread safety, task-state correctness, and performance improvements around encoding and task restoration.

- Current podspec version: `3.2.9`
- Minimum platform: `iOS 12.0+`
- Language baseline: `Swift 5.0+`
- Distribution: CocoaPods, Swift Package Manager, and manual source integration

## Installation

### CocoaPods

```ruby
platform :ios, '12.0'
use_frameworks!

target 'YourTargetName' do
  pod 'Tiercel'
end
```

Then run:

```bash
pod install
```

### Swift Package Manager

In Xcode, choose `File > Add Package Dependencies...` and use:

```text
https://github.com/Danie1s/Tiercel.git
```

### Manual Integration

Drag the `Sources` directory into your project and make sure the files are included in the desired target.

## Quick Start

```swift
import Tiercel

var configuration = SessionConfiguration()
configuration.allowsCellularAccess = true
configuration.maxConcurrentTasksLimit = 3

let manager = SessionManager("downloads", configuration: configuration)

let task = manager.download("https://example.com/video.mp4")

task?.progress(onMainQueue: true) { task in
    print("progress:", task.progress.fractionCompleted)
}.success { task in
    print("saved to:", task.filePath)
}.failure { _ in
    print("download failed")
}
```

You can control downloads by URL or by task instance:

```swift
let url = "https://example.com/video.mp4"

manager.start(url)
manager.suspend(url)
manager.cancel(url)
manager.remove(url, completely: false)

if let task = task {
    manager.start(task)
    manager.suspend(task)
    manager.cancel(task)
    manager.remove(task, completely: false)
}
```

Tiercel also supports batch creation and start:

```swift
let urls = [
    "https://example.com/episode-1.mp4",
    "https://example.com/episode-2.mp4"
]

let tasks = manager.multiDownload(urls)
print(tasks.count)
```

## Background Downloads And Relaunch Recovery

Tiercel persists task state and resume data to disk, so downloads can be restored after the app relaunches. If the user force-quits the app, iOS stops background execution until the next launch; once the app is opened again, Tiercel can recover eligible downloads and continue from stored state.

To support native background session callbacks, wire the completion handler from `AppDelegate` to the matching `SessionManager`:

```swift
let downloadManagers = [managerA, managerB]

func application(_ application: UIApplication,
                 handleEventsForBackgroundURLSession identifier: String,
                 completionHandler: @escaping () -> Void) {
    for manager in downloadManagers where manager.identifier == identifier {
        manager.completionHandler = completionHandler
        break
    }
}
```

## Network Policy And File Validation

`SessionConfiguration` lets you tune network behavior for different products or environments:

```swift
var configuration = SessionConfiguration()
configuration.maxConcurrentTasksLimit = 3
configuration.allowsCellularAccess = true
configuration.allowsConstrainedNetworkAccess = true
configuration.allowsExpensiveNetworkAccess = true

let manager = SessionManager("downloads", configuration: configuration)
```

You can also validate downloaded files when integrity matters:

```swift
task?.validateFile(code: "9e2a3650530b563da297c9246acaad5c",
                   type: .md5,
                   onMainQueue: true) { task in
    if task.validation == .correct {
        print("file is valid")
    } else {
        print("file is invalid")
    }
}
```

## Demo

Open `Demo/Tiercel-Demo.xcodeproj` to explore:

- Single-file downloads
- Batch downloads
- Multiple isolated download managers
- Background session event handling
- Validation and progress callbacks

![Tiercel demo 1](Images/1.gif)
![Tiercel demo 2](Images/2.gif)

## Docs And Migration

- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Wiki](https://github.com/Danie1s/Tiercel/wiki)
- [Tiercel 3.0 Migration Guide](https://github.com/Danie1s/Tiercel/wiki/Tiercel-3.0-%E8%BF%81%E7%A7%BB%E6%8C%87%E5%8D%97)
- [Objective-C Bridge](https://github.com/Danie1s/TiercelObjCBridge)

## Repository Layout

- `Sources/General`: core session, task, cache, and status-management logic
- `Sources/Extensions`: lightweight helpers used across the framework
- `Sources/Utility`: checksum and resume-data utilities
- `Demo`: sample iOS app for evaluation and manual testing

## License

Tiercel is available under the MIT license. See [LICENSE](LICENSE) for details.
