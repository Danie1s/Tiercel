<div align=center>
<img src="https://raw.githubusercontent.com/Danie1s/Tiercel/master/Images/logo.png"/>
</div>

[![Version](https://img.shields.io/cocoapods/v/Tiercel.svg?style=flat)](http://cocoapods.org/pods/Tiercel)
[![Platform](https://img.shields.io/cocoapods/p/Tiercel.svg?style=flat)](http://cocoapods.org/pods/Tiercel)
[![Language](https://img.shields.io/badge/language-swift-red.svg?style=flat)]()
[![SPM](https://img.shields.io/badge/SPM-supported-DE5C43.svg?style=flat)](https://swift.org/package-manager/)
[![Support](https://img.shields.io/badge/support-iOS%2010%2B%20-brightgreen.svg?style=flat)](https://www.apple.com/nl/ios/)
[![License](https://img.shields.io/cocoapods/l/Tiercel.svg?style=flat)](http://cocoapods.org/pods/Tiercel)

Tiercel 是一个简单易用、功能丰富的纯 Swift 下载框架，支持原生级别后台下载，拥有强大的任务管理功能，可以满足下载类 APP 的大部分需求。

如果你使用的开发语言是 Objective-C ，可以使用 [TiercelObjCBridge](https://github.com/Danie1s/TiercelObjCBridge) 进行桥接

- [Tiercel 3.0](#tiercel-30)
- [特性](#特性)
- [环境要求](#环境要求)
- [集成](#集成)
- [Demo](#demo)
- [用法](#用法)
  - [基本用法](#基本用法)
  - [后台下载](#后台下载)
  - [文件校验](#文件校验)
  - [更多](#更多)
- [License](#license)



## Tiercel 3.0

Tiercel 3.0 大幅提高了性能，拥有更完善的错误处理，提供了更多方便的 API。从 Tiercel 2.0 升级到 Tiercel 3.0 是很简单的，强烈推荐所有开发者都进行升级，具体请查看 [Tiercel 3.0 迁移指南](https://github.com/Danie1s/Tiercel/wiki/Tiercel-3.0-%E8%BF%81%E7%A7%BB%E6%8C%87%E5%8D%97)

## 特性

- [x] 支持原生级别的后台下载
- [x] 支持离线断点续传，App 无论 crash 还是被手动 Kill 都可以恢复下载
- [x] 拥有精细的任务管理，每个下载任务都可以单独操作和管理
- [x] 支持创建多个下载模块，每个模块互不影响
- [x] 每个下载模块拥有单独的管理者，可以对总任务进行操作和管理
- [x] 支持批量操作
- [x] 内置了下载速度、剩余时间等常见的下载信息
- [x] 支持自定义日志
- [x] 支持下载任务排序
- [x] 链式语法调用
- [x] 支持控制下载任务的最大并发数
- [x] 支持文件校验
- [x] 线程安全



## 环境要求

- iOS 10.0+
- Xcode 11.0+
- Swift 5.0+



## 安装

### CocoaPods

Tiercel 支持 CocoaPods 集成，首先需要使用以下命令安装 CocoaPod：

```bash
$ gem install cocoapods
```

在`Podfile`文件中

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '10.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'Tiercel'
end
```

最后运行命令

```bash
$ pod install
```

### Swift Package Manager

从 Xcode 11 开始，集成了 Swift Package Manager，使用起来非常方便。Tiercel 也支持通过 Swift Package Manager 集成。

在 Xcode 的菜单栏中选择 `File > Swift Packages > Add Pacakage Dependency`，然后在搜索栏输入

`git@github.com:Danie1s/Tiercel.git`，即可完成集成

### 手动集成

Tiercel 也支持手动集成，只需把本项目文件夹中的`Tiercel`文件夹拖进需要集成的项目即可



## Demo

打开本项目文件夹中 `Tiercel.xcodeproj` ，可以直接运行 Demo

<img src="https://raw.githubusercontent.com/Danie1s/Tiercel/master/Images/1.gif">
<img src="https://raw.githubusercontent.com/Danie1s/Tiercel/master/Images/2.gif">


## 用法

### 基本用法

一行代码开启下载

```swift
// 创建下载任务并且开启下载，同时返回可选类型的DownloadTask实例，如果url无效，则返回nil
let task = sessionManager.download("http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg")

// 批量创建下载任务并且开启下载，返回有效url对应的任务数组，urls需要跟fileNames一一对应
let tasks = sessionManager.multiDownload(URLStrings)
```

可以对任务设置状态回调

```swift
let task = sessionManager.download("http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg")

task?.progress(onMainQueue: true) { (task) in
    let progress = task.progress.fractionCompleted
    print("下载中, 进度：\(progress)")
}.success { (task) in
    print("下载完成")
}.failure { (task) in
    print("下载失败")
}
```

可以通过 URL 对下载任务进行操作，也可以直接操作下载任务

```swift
let URLString = "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg"

// 通过 URL 对下载任务进行操作
sessionManager.start(URLString)
sessionManager.suspend(URLString)
sessionManager.cancel(URLString)
sessionManager.remove(URLString, completely: false)

// 直接对下载任务进行操作
sessionManager.start(task)
sessionManager.suspend(task)
sessionManager.cancel(task)
sessionManager.remove(task, completely: false)
```



### 后台下载

从 Tiercel 2.0 开始支持原生的后台下载，只要使用 Tiercel 开启了下载任务：

- 手动 Kill App，任务会暂停，重启 App 后可以恢复进度，继续下载
- 只要不是手动 Kill App，任务都会一直在下载，例如：
  - App 退回后台
  - App 崩溃或者被系统关闭
  - 重启手机

如果想了解后台下载的细节和注意事项，可以查看：[iOS 原生级别后台下载详解](https://github.com/Danie1s/Tiercel/wiki/iOS-%E5%8E%9F%E7%94%9F%E7%BA%A7%E5%88%AB%E5%90%8E%E5%8F%B0%E4%B8%8B%E8%BD%BD%E8%AF%A6%E8%A7%A3)



### 文件校验

Tiercel 提供了文件校验功能，可以根据需要添加，校验结果在回调的`task.validation`里

```swift

let task = sessionManager.download("http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg")
// 回调闭包可以选择是否在主线程上执行
task?.validateFile(code: "9e2a3650530b563da297c9246acaad5c",
                   type: .md5,
                   onMainQueue: true)
                   { (task) in
    if task.validation == .correct {
        // 文件正确
    } else {
        // 文件错误
    }
}
```



### 更多

有关 Tiercel 3.0 的详细使用方法和升级迁移，请查看 [Wiki](https://github.com/Danie1s/Tiercel/wiki)




## License

Tiercel is available under the MIT license. See the LICENSE file for more info.


