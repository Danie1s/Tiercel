<div align=center>
<img src="https://github.com/Danie1s/Tiercel/blob/master/Images/logo.png"/>
</div>

[![Version](https://img.shields.io/cocoapods/v/Tiercel.svg?style=flat)](http://cocoapods.org/pods/Tiercel)
[![Platform](https://img.shields.io/cocoapods/p/Tiercel.svg?style=flat)](http://cocoapods.org/pods/Tiercel)
[![Language](https://img.shields.io/badge/language-swift-red.svg?style=flat)]()
[![Support](https://img.shields.io/badge/support-iOS%208%2B%20-brightgreen.svg?style=flat)](https://www.apple.com/nl/ios/)
[![License](https://img.shields.io/cocoapods/l/Tiercel.svg?style=flat)](http://cocoapods.org/pods/Tiercel)


Tiercel是一个简单易用且功能丰富的纯Swift下载框架，支持原生级别后台下载，拥有强大的任务管理功能，满足下载类APP的大部分需求。

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



## Tiercel 2：

Tiercel 2 是一个全新的版本，下载的实现基于`URLSessionDownloadTask`，支持原生的后台下载，功能更加强大，使用方式也有了一些改变，请注意新版的使用方法。

旧版本基于`URLSessionDataTask`，不支持后台下载，已经移至`dataTask`分支，原则上不再更新，如果不需要后台下载功能，或者不想迁移到新版，可以直接下载`dataTask`分支的源码使用，也可以在`Podfile`里使用以下方式安装：

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'Tiercel', :git => 'https://github.com/Alamofire/Alamofire.git', :branch => 'dataTask'
end
```

## Features:

- [x] 原生级别的后台下载
- [x] 支持离线断点续传，无论crash还是手动Kill App都不会影响
- [x] 精细的任务管理，每个下载任务都可以单独管理操作和状态回调
- [x] 支持多个下载模块，每个模块拥有一个管理者，每个模块互不影响
- [x] 下载模块的管理者也有总任务的状态回调
- [x] 可以直接获取下载速度、剩余时间等常见的下载信息
- [x] 链式语法调用
- [x] 支持控制下载任务的最大并发数
- [x] 支持文件校验
- [x] 线程安全

## Requirements

- iOS 8.0+
- Xcode 10.0+
- Swift 4.2+

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

To run the example project, clone the repo, and run `Tiercel.xcodeproj` .

<img src="https://github.com/Danie1s/Tiercel/blob/master/Images/3.gif" width="50%" height="50%">

<img src="https://github.com/Danie1s/Tiercel/blob/master/Images/4.gif" width="50%" height="50%">

## Usage

### 配置

Tiercel内置一个全局的`default`单例，因为需要支持原生后台下载，需要在`AppDelegate` 文件里配置

```swift
// 在AppDelegate文件里

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // 如果有使用内置全局的default单例，必须在此方法内调用一次，否则不会在App启动的时候初始化
    print(TRManager.default)
    
    // Tiercel虽然支持在任何地方进行配置，但最好在这里进行初始化的配置
   	TRManager.default.configuration.allowsCellularAccess = false
    
    return true
}

// 必须在此方法把identifier对应的completionHandler保存起来
func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {

    if TRManager.default.identifier == identifier {
        TRManager.default.completionHandler = completionHandler
    }

}
```

以上为内置的`default`单例配置方法，如果需要使用多个下载模块，或者需要自定义`TRManager`，可参照`Demo`

### 基本用法

一行代码开启下载

```swift
// 创建下载任务并且开启下载
TRManager.default.download("http://api.gfs100.cn/upload/20171219/201712191530562229.mp4")
```

如果需要设置回调

```swift
TRManager.default.download("http://api.gfs100.cn/upload/20171219/201712191530562229.mp4", fileName: "视频.mp4", progressHandler: { (task) in
    let progress = task.progress.fractionCompleted
    print("下载中, 进度：\(progress)")
}, successHandler: { (task) in
    print("下载成功")
}) { (task) in
    print("下载失败")
}
```

下载任务的管理和操作

```swift
// 创建下载任务并且开启下载，同时返回可选类型的TRDownloadTask实例，如果URLString无效，则返回nil
let task = TRManager.default.download(URLString)
// 根据URLString查找下载任务，返回可选类型的TRTask实例，如果不存在，则返回nil
let task = TRManager.default.fetchTask(URLString)

// 开始下载
// 如果调用suspend暂停了下载，可以调用这个方法继续下载
TRManager.default.start(URLString)

// 暂停下载
TRManager.default.suspend(URLString)

// 取消下载，没有下载完成的任务会被移除，不保留缓存，已经下载完成的不受影响
TRManager.default.cancel(URLString)

// 移除下载，任何状态的任务都会被移除，没有下载完成的缓存文件会被删除，已经下载完成的文件可以选择是否保留
TRManager.default.remove(URLString, completely: false)
```



### TRManager

`TRManager`是下载任务的管理者，管理当前模块所有下载任务，内置一个全局的`default`单例，如果需要多个下载模块，或者需要自定义`TRManager`，可以手动创建`TRManager`实例。**⚠️⚠️⚠️** 按照苹果官方文档的要求，`TRManager`实例必须在App启动的时候创建，并且为方便使用，最好是作为`AppDelegate`的属性，或者是全局变量，还需要在`AppDelegate` 文件里配置，具体请参照`Demo`。**⚠️⚠️⚠️** 

```swift
///  初始化方法
///
/// - Parameters:
///   - identifier: 设置TRManager实例的标识，区分不同的下载模块，同时为urlSession的标识，原生级别的后台下载必须要有唯一标识
public init(_ identifier: String) {
    // 实现的代码... 
}
```

**Tiercel的设计理念是一个URLString对应一个下载任务，所有操作都必须通过TRManager实例进行，URLString作为下载任务的唯一标识。**

除了可以对单个任务进行操作，TRManager也提供了对所有任务同时操作的API

```swift
// 批量开启下载任务，返回有效URLString对应的任务数组，URLStrings需要跟fileNames一一对应
let tasks = TRManager.default.multiDownload(URLStrings, fileNames: fileNames)

TRManager.default.totalStart()
TRManager.default.totalSuspend()
TRManager.default.totalCancel()
TRManager.default.totalRemove(completely: false)
```

TRManager作为所有下载任务的管理者，也可以设置回调

```swift
// 回调闭包的参数是TRManager实例，可以通过TRManager实例得到任何相关的信息，把灵活度最大化
// 回调闭包都是在主线程运行
// progress 闭包：只要有一个任务正在下载，就会触发
// success 闭包：只有一种情况会触发：
//    所有任务都下载成功(取消和移除的任务会被移除然后销毁，不再被manager管理) ，这时候manager.status == .succeeded
// failure 闭包：只要manager.status != .succeeded，就会触发：
//    1. 所有任务都结束，但有一个或者多个是失败的，这时候manager.status == .failed
//    2. 调用全部取消的方法，或者剩下一个任务的时候把这个任务取消，这时候manager.status == .cancel
//    3. 调用全部移除的方法，或者剩下一个任务的时候把这个任务移除，这时候manager.status == .remove
//    4. 调用全部暂停的方法，或者没有等待运行的任务，也没有正在运行的任务，这时候manager.status == .suspend
downloadManager.progress { (manager) in
    let progress = manager.progress.fractionCompleted
    print("downloadManager运行中, 总进度：\(progress)")
    }.success { (manager) in
        if manager.status == .suspend {
            print("所有下载任务都暂停了")
        } else if manager.status == .completed {
            print("所有下载任务都成功了")
        }
    }.failure { (manager) in
        if manager.status == .failed {
            print("存在下载失败的任务")
        } else if manager.status == .cancel {
            print("所有下载任务都取消了")
        } else if manager.status == .remove {
            print("所有下载任务都移除了")
        }
}
```

TRManager的主要属性

```swift
// 设置内置日志打印等级，如果为none则不打印
public static var logLevel: TRLogLevel = .detailed
// 是否需要对networkActivityIndicator进行管理
public static var isControlNetworkActivityIndicator = true
// TRManager的状态
public var status: TRStatus = .waiting
// TRManager的缓存管理实例
public var cache: TRCache
// TRManager的进度
public var progress: Progress
// 设置请求超时时间
public var timeoutIntervalForRequest = 30.0
// 所有下载中的任务加起来的总速度
public private(set) var speed: Int64 = 0
// 所有下载中的任务需要的剩余时间
public private(set) var timeRemaining: Int64 = 0

// manager管理的下载任务，取消和移除的任务会被销毁，但操作是异步的，在回调闭包里面获取才能保证正确
public var tasks: [TRTask] = []
```



### TRCache

TRCache是Tiercel中负责管理缓存下载任务信息和下载文件的类。同样地，TRCache没有设计成单例模式，TRCache实例一般作为TRManager实例的属性来使用，如果需要跨控制器使用，那么只需要创建跟TRManager实例同样名字的TRCache实例即可操作对应模块的缓存信息和文件。

```swift
/// 初始化方法
///
/// - Parameters:
///   - name: 设置TRCache实例的名字，一般由TRManager实例创建时传递
///   - isStoreInfo: 是否把下载任务的相关信息持久化到沙盒，一般由TRManager实例创建时传递
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

TRDownloadTask是Tiercel中的下载任务类，继承自TRTask。**Tiercel的设计理念是一个URLString对应一个下载任务，所有操作都必须通过TRManager实例进行，URLString作为下载任务的唯一标识**。所以TRDownloadTask实例都是由TRManager实例创建，单独创建没有意义。

主要属性

```swift
// 保存到沙盒的下载文件的文件名，如果在下载的时候没有设置，则默认使用url的最后一部分
public internal(set) var fileName: String
// 下载任务对应的URLString
public var URLString: String
// 下载任务的状态
public var status: TRStatus = .waiting
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

下载任务的回调，可以在使用TRManager实例开启下载的时候设置，也可以在获得TRDownloadTask实例后进行设置

```swift
let task = downloadManager.fetchTask(URLString)

// 回调闭包的参数都是TRDownloadTask实例，因为开发者可以通过TRDownloadTask实例得到任何相关的信息，把灵活度最大化
// 回调闭包都是在主线程运行
// progress 闭包：如果任务正在下载，就会触发
// success 闭包：有两种情况会触发：
//    1. 任务已经下载过了，或者任务下载完成，这时候task.status == .completed
//    2. 暂停下载任务，这时候task.status == .suspend
// failure 闭包：有三种情况会触发：
//    1. 任务下载失败，这时候task.status == .failed
//    2. 取消任务，这时候task.status == .cancel
//    3. 移除任务，或者剩下一个任务的时候把这个任务移除，这时候manager.status == .remove
task.progress { (task) in
     let progress = task.progress.fractionCompleted
     print("下载中, 进度：\(progress)")
    }
    .success({ (task) in
         if task.status == .suspend {
            print("下载暂停")
        } else if task.status == .completed {
            print("下载完成")
        } 
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

对下载任务操作，必须通过TRManager实例进行，不能用TRDownloadTask实例直接操作

- 开启
- 暂停
- 取消，会从TRManager实例中的tasks中移除，但保留没有下载完成的缓存文件
- 移除，已经完成的任务也会被移除，没有下载完成的缓存文件会被删除，已经下载完成的文件可以选择是否保留

**注意：对下载中的任务进行暂停、取消和移除操作，结果是异步回调的，在回调闭包里面获取状态才能保证正确**



###  后台下载

~~如果需要开启后台下载，只需要在项目的info.plist中添加Required background modes -> App downloads content from the network~~

目前正在寻找解决办法



## License

Tiercel is available under the MIT license. See the LICENSE file for more info.


