# Tiercel

[![Version](https://img.shields.io/cocoapods/v/Tiercel.svg?style=flat)](http://cocoapods.org/pods/Tiercel)
[![License](https://img.shields.io/cocoapods/l/Tiercel.svg?style=flat)](http://cocoapods.org/pods/Tiercel)
[![Platform](https://img.shields.io/cocoapods/p/Tiercel.svg?style=flat)](http://cocoapods.org/pods/Tiercel)

Tiercel是一个非常简单易用且功能丰富的纯Swift下载框架。最大的特点就是拥有强大的任务管理功能和可以直接获取常见的下载信息，并且只要加上一些简单的UI，就可以实现一个下载类APP的大部分功能。

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Example](#example)
- [Usage](#usage)
  - [最简单的用法](#最简单的用法)
  - [TRManager](#trmanager)
  - [TRCache](#trcache)
  - [TRDownloadTask](#trdownloadtask)
  - [后台下载](#后台下载)
- [License](#license)

## Features:

- [x] 支持大文件下载
- [x] 支持离线断点续传，APP关闭后依然可以恢复所有下载任务
- [x] 每个下载任务都可以单独管理操作
- [x] 每个下载任务和manager都有进度回调、成功回调和失败回调
- [x] 弃用单例模式，APP里面可以有多个manager，可以根据需要区分不同的下载模块
- [x] 内置了常见的下载信息，并且可以选择是否持久化下载任务信息
- [x] 支持后台下载
- [x] 链式语法调用
- [x] 可以控制下载的最大并发数
- [x] 线程安全

## Requirements

- iOS 8.0+
- Xcode 9.0+
- Swift 4.0+​

## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 1.1+ is required to build Tiercel.

To integrate Tiercel into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'Tiercel'
end
```

Then, run the following command:

```bash
$ pod install
```

### Manually

If you prefer not to use any of the aforementioned dependency managers, you can integrate Tiercel into your project manually.

## Example

To run the example project, clone the repo, and run `Example.xcodeproj` from the Example directory.

<img src="https://github.com/Danie1s/Tiercel/blob/master/Images/1.gif" width="30%" height="30%">

<img src="https://github.com/Danie1s/Tiercel/blob/master/Images/2.gif" width="30%" height="30%">

## Usage

### 最简单的用法

只需要简单的几行代码即可开启下载

```swift
let URLString = "http://120.25.226.186:32812/resources/videos/minion_01.mp4"
let downloadManager = TRManager()
// 创建下载任务并且开启下载
downloadManager.download(URLString)
```

当然也可以对下载任务设置回调

```swift
downloadManager.download(URLString, fileName: "小黄人1.mp4", progressHandler: { (task) in
    let progress = task.progress.fractionCompleted                                                                        
    print("下载中, 进度：\(progress)")
}, successHandler: { (task) in
    print("下载完成")
}) { (task) in
    print("下载失败")
}
```

下载任务的管理和操作

```swift
// 创建下载任务并且开启下载，同时返回可选类型的TRDownloadTask对象，如果URLString无效，则返回nil
let task = downloadManager.download(URLString)
// 根据URLString查找下载任务，返回可选类型的FCTask对象，如果不存在，则返回nil
let task = downloadManager.fetchTask(URLString)

// 开始下载
// 如果设置了downloadManager.isStartDownloadImmediately = false，需要手动开启下载
// 如果调用suspend暂停了下载，可以调用这个方法继续下载
downloadManager.start(URLString)

// 暂停下载
downloadManager.suspend(URLString)

// 取消下载，没有下载完成的任务会被移除，但保留没有下载完成的缓存文件
downloadManager.cancel(URLString)

// 移除下载，所有任务都会被移除，保留已经下载完成的文件，但没有下载完成的缓存文件会被删除
downloadManager.remove(URLString)
```



### TRManager

TRManager是下载任务的管理者，管理所有下载任务，要使用Tiercel进行下载，必须要先创建TRManager对象。Tiercel没有设计成单例模式，因为一个APP可能会有多个不同的下载模块，开发者可以根据需求创建多个TRManager对象来进行下载。

```swift
///  初始化方法
///
/// - Parameters:
///   - name: 设置TRManager对象的名字，区分不同的下载模块，每个模块中下载相关的文件会保存到对应的沙盒目录
///   - MaximumRunning: 下载的最大并发数
///   - isStoreInfo: 是否把下载任务的相关信息持久化到沙盒，如果是，则初始化完成后自动恢复上次的任务
public init(_ name: String? = nil, MaximumRunning: Int? = nil, isStoreInfo: Bool = false) {
    // 实现的代码... 
}
```

开启下载任务，并且对其进行管理。**Tiercel的设计理念是一个URLString对应一个下载任务，所有操作都必须通过TRManager对象进行，URLString作为下载任务的唯一标识。**

```swift
let URLString = "http://120.25.226.186:32812/resources/videos/minion_01.mp4"
let downloadManager = TRManager()

// 如果URLString无效，则返回nil
let task = downloadManager.download(URLString, fileName: "小黄人1.mp4", progressHandler: {  (task) in
    let progress = task.progress.fractionCompleted                                                                        
    print("下载中, 进度：\(progress)")
}, successHandler: { (task) in
    print("下载完成")
}) { (task) in
    print("下载失败")
}

// 批量开启下载任务，返回有效URLString对应的任务数组，URLStrings需要跟fileNames一一对应
let tasks = downloadManager.multiDownload(URLStrings, fileNames: fileNames)


// 根据URLString查找下载任务，返回可选类型的FCTask对象
// let task = downloadManager.fetchTask(URLString)

// 开始下载
// 如果设置了downloadManager.isStartDownloadImmediately = false，需要手动开启下载
// 如果调用suspend暂停了下载，可以调用这个方法继续下载
downloadManager.start(URLString)

// 暂停下载
downloadManager.suspend(URLString)

// 取消下载，没有下载完成的任务会被移除，但保留没有下载完成的缓存文件
downloadManager.cancel(URLString)

// 删除下载，已经完成的任务也会被移除，保留已经下载完成的文件，但没有下载完成的缓存文件会被删除
downloadManager.remove(URLString)
```

TRManager也提供了对所有任务同时操作的API

```swift
downloadManager.totalStart()
downloadManager.totalSuspend()
downloadManager.totalCancel()
downloadManager.totalRemove()
```

TRManager作为所有下载任务的管理者，也可以设置回调

```swift
// 回调闭包的参数都是TRManager对象，因为开发者可以通过TRManager对象得到任何相关的信息，把灵活度最大化
// 回调闭包都是在主线程运行
// progress 闭包：只要有一个任务正在下载，就会触发
// success 闭包：有两种情况会触发：
//    1. 所有任务都下载成功(取消和移除的任务会被移除然后销毁，不再被manager管理) ，这时候manager.status == .completed
//    2. 任何一个任务的状态都不是成功或者失败，且没有等待运行的任务，也没有正在运行的任务，这时候manager.status == .suspend
// failure 闭包：有三种情况会触发：
//    1. 每个任务的状态是成功或者失败，且有一个是失败的，这时候manager.status == .failed
//    2. 调用全部取消的方法，或者剩下一个任务的时候把这个任务取消，这时候manager.status == .cancel
//    3. 调用全部移除的方法，或者剩下一个任务的时候把这个任务移除，这时候manager.status == .remove
downloadManager.progress { (manager) in
    let progress = manager.progress.fractionCompleted
    print("downloadManager运行中, 总进度：\(progress)")
    }.success { (manager) in
        if manager.status == .suspend {
            print("manager暂停了")
        } else if manager.status == .completed {
            print("所有下载任务都下载成功")
        }
    }.failure { (manager) in
        if manager.status == .failed {
            print("存在下载失败的任务")
        } else if manager.status == .cancel {
            print("manager取消了")
        } else if manager.status == .remove {
            print("manager移除了")
        }
}
```

**Tiercel的销毁**

```swift
// 由于Tiercel是使用URLSession实现的，session需要手动销毁，所以当不再需要使用Tiercel也需要手动销毁
// 一般在控制器中添加以下代码
deinit {
    downloadManager.invalidate()
}
```

TRManager的主要属性

```swift
// 设置内置日志打印等级，如果为none则不打印
public static var logLevel: TRLogLevel = .high
// 设置是否创建任务后马上下载，默认为是
public var isStartDownloadImmediately = true
// TRManager的状态
public var status: FCStatus = .waiting
// TRManager的缓存管理对象
public var cache: TRCache
// TRManager的进度
public var progress: Progress
// 设置请求超时时间
public var timeoutIntervalForRequest = 30.0
// 所有下载中的任务加起来的总速度
public private(set) var speed: Int64 = 0
// 所有下载中的任务需要的剩余时间
public private(set) var timeRemaining: Int64 = 0

// manager管理的下载任务，取消和移除的任务会被销毁，不会在数组里，但操作是异步的，马上获取的tasks可能不正确
public var tasks: [FCTask] = []
```



 ### TRCache

TRCache是Tiercel中负责管理缓存下载任务信息和下载文件的类。同样地，TRCache没有设计成单例模式，TRCache对象一般作为TRManager对象的属性来使用，如果需要跨控制器使用，那么只需要创建跟TRManager对象同样名字的TRCache对象即可操作对应模块的缓存信息和文件。

```swift
/// 初始化方法
///
/// - Parameters:
///   - name: 设置TRCache对象的名字，一般由TRManager对象创建时传递
///   - isStoreInfo: 是否把下载任务的相关信息持久化到沙盒，一般由TRManager对象创建时传递
public init(_ name: String, isStoreInfo: Bool = false) {
    // 实现的代码...
}
```

主要属性

```swift
// 下载模块的目录路径
public let downloadPath: String

// 没有完成的下载文件缓存的目录路径
public let downloadTmpPath: String

// 下载完成的文件的目录路径
public let downloadFilePath: String
```

主要API分成几大类：

- 检查沙盒是否存在文件

- 移除跟下载任务相关的文件

- 保存跟下载任务相关的文件

- 读取下载任务相关的文件，获得下载任务相关的信息

  ​



### TRDownloadTask

TRDownloadTask是Tiercel中的下载任务类，继承自FCTask。**Tiercel的设计理念是一个URLString对应一个下载任务，所有操作都必须通过TRManager对象进行，URLString作为下载任务的唯一标识。**所以TRDownloadTask对象都是由TRManager对象创建，单独创建没有意义。

主要属性

```swift
// 保存到沙盒的下载文件的文件名，如果在下载的时候没有设置，则默认使用url的最后一部分
public internal(set) var fileName: String
// 下载任务对应的URLString
public var URLString: String
// 下载任务的状态
public var status: FCStatus = .waiting
// 下载任务的进度
public var progress: Progress = Progress()
// 下载任务的开始日期
public var startDate: TimeInterval = 0
// 下载任务的结束日期
public var endDate: TimeInterval = Date().timeIntervalSince1970
// 下载任务的速度
public var speed: Int64 = 0
// 下载任务的剩余时间
public var timeRemaining: Int64 = 0
```

下载任务的回调，可以在使用TRManager对象开启下载的时候设置，也可以在获得TRDownloadTask对象后进行设置

```swift
let task = downloadManager.fetchTask(URLString)

// 回调闭包的参数都是TRDownloadTask对象，因为开发者可以通过TRDownloadTask对象得到任何相关的信息，把灵活度最大化
// 回调闭包都是在主线程运行
// progress 闭包：如果任务正在下载，就会触发
// success 闭包：任务已经下载过了，或者任务下载完成时，会触发
// failure 闭包：有三种情况会触发：
//    1. 任务下载失败，这时候task.status == .failed
//    2. 取消任务，这时候task.status == .cancel
//    3. 移除任务，或者剩下一个任务的时候把这个任务移除，这时候manager.status == .remove
task.progress { (task) in
     let progress = task.progress.fractionCompleted
     printLog("下载中, 进度：\(progress)")
    }
    .success({ (task) in
        printLog("下载完成")
    })
    .failure({  (task) in
        if task.status == .failed {
            print("下载失败")
        } else if task.status == .cancel {
            print("取消任务")
        } else if task.status == .remove {
            print("移除任务")
        }
    })
```

对下载任务操作，必须通过TRManager对象进行，不能用TRDownloadTask对象直接操作

- 开启
- 暂停
- 取消，会从TRManager对象中的tasks中移除，但保留没有下载完成的缓存文件
- 移除，已经完成的任务也会被移除，保留已经下载完成的文件，但没有下载完成的缓存文件会被删除

**注意：取消和移除的任务会被销毁，会从TRManager对象的tasks中移除，但操作是异步的，马上获取的tasks可能不正确**



###  后台下载

如果需要开启后台下载，只需要在项目的info.plist中添加Required background modes -> App downloads content from the network



## License

Tiercel is available under the MIT license. See the LICENSE file for more info.


