<div align="center">
  <img src="Images/logo.png" alt="Tiercel logo" width="600" />
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

Tiercel 是一个纯 Swift 的 iOS 下载框架，专注于原生级别后台下载、断点续传以及精细化任务管理。它适合那些不满足于“一次性发起下载请求”的应用场景，比如批量操作、下载模块隔离、应用重启后的任务恢复、文件校验，以及面向生产环境的进度回调与状态管理。

如果你的项目使用 Objective-C，可以配合 [TiercelObjCBridge](https://github.com/Danie1s/TiercelObjCBridge) 使用。
如果需要私密报告安全漏洞，请查看 [SECURITY.md](SECURITY.md)。
如果你想参与贡献，请先查看英文版贡献指南 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 为什么选择 Tiercel

- 基于 `URLSession` 的原生级别后台下载能力。
- 通过持久化任务信息和 resume data，在应用重启后恢复下载。
- 支持单任务和管理器级别的开始、暂停、取消、删除与批量操作。
- 支持多个 `SessionManager` 实例，便于隔离不同下载业务。
- 支持并发数、蜂窝网络、受限网络和高成本网络等策略配置。
- 内置下载速度、剩余时间与文件校验回调。
- 内部状态具备线程安全设计，更适合真实下载场景。

## 项目状态

Tiercel 目前仍在持续维护 3.2.x 分支。最近的更新主要集中在线程安全、任务状态正确性，以及编码与任务恢复相关的性能优化。

- 当前 podspec 版本：`3.2.9`
- 最低平台要求：`iOS 12.0+`
- 语言基线：`Swift 5.0+`
- 集成方式：CocoaPods、Swift Package Manager、手动集成

## 安装

### CocoaPods

```ruby
platform :ios, '12.0'
use_frameworks!

target 'YourTargetName' do
  pod 'Tiercel'
end
```

然后执行：

```bash
pod install
```

### Swift Package Manager

在 Xcode 中选择 `File > Add Package Dependencies...`，然后使用：

```text
https://github.com/Danie1s/Tiercel.git
```

### 手动集成

将 `Sources` 目录拖入你的工程，并确保这些文件被加入到目标 target 中。

## 快速开始

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

你既可以通过 URL 控制下载，也可以直接操作任务实例：

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

Tiercel 也支持批量创建并开始下载任务：

```swift
let urls = [
    "https://example.com/episode-1.mp4",
    "https://example.com/episode-2.mp4"
]

let tasks = manager.multiDownload(urls)
print(tasks.count)
```

## 后台下载与重启恢复

Tiercel 会将任务状态和 resume data 持久化到磁盘，因此应用重新启动后可以恢复下载。如果用户手动强制结束应用，iOS 会停止后台执行；当应用再次启动后，Tiercel 可以从已保存的状态中恢复符合条件的下载任务。

为了支持原生后台 session 回调，需要在 `AppDelegate` 中把 completion handler 交给对应的 `SessionManager`：

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

## 网络策略与文件校验

`SessionConfiguration` 可以针对不同业务场景调整网络行为：

```swift
var configuration = SessionConfiguration()
configuration.maxConcurrentTasksLimit = 3
configuration.allowsCellularAccess = true
configuration.allowsConstrainedNetworkAccess = true
configuration.allowsExpensiveNetworkAccess = true

let manager = SessionManager("downloads", configuration: configuration)
```

当你需要保证文件完整性时，也可以在下载完成后进行校验：

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

打开 `Demo/Tiercel-Demo.xcodeproj`，可以快速体验：

- 单文件下载
- 批量下载
- 多下载管理器隔离
- 后台 session 事件处理
- 文件校验与进度回调

![Tiercel demo 1](Images/1.gif)
![Tiercel demo 2](Images/2.gif)

## 文档与迁移

- [贡献指南（英文）](CONTRIBUTING.md)
- [安全策略](SECURITY.md)
- [Wiki](https://github.com/Danie1s/Tiercel/wiki)
- [Tiercel 3.0 迁移指南](https://github.com/Danie1s/Tiercel/wiki/Tiercel-3.0-%E8%BF%81%E7%A7%BB%E6%8C%87%E5%8D%97)
- [Objective-C Bridge](https://github.com/Danie1s/TiercelObjCBridge)

## 仓库结构

- `Sources/General`：核心的 session、task、cache 与状态管理逻辑
- `Sources/Extensions`：框架内部使用的轻量扩展
- `Sources/Utility`：文件校验和 resume data 相关工具
- `Demo`：用于评估与手动验证的示例应用

## License

Tiercel 基于 MIT 协议开源，详情请查看 [LICENSE](LICENSE)。
