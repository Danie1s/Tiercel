<div align=center>
<img src="https://raw.githubusercontent.com/Danie1s/Tiercel/master/Images/logo.png"/>
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
  - [配置](#配置)
  - [基本用法](#基本用法)
  - [后台下载](#后台下载)
  - [文件校验](#文件校验)
  - [SessionManager](#sessionmanager)
  - [SessionConfiguration](#sessionconfiguration)
  - [DownloadTask](#downloadtask)
  - [Cache](#cache)
- [License](#license)



## Tiercel 2:

Tiercel 2 是全新的版本，下载实现基于`URLSessionDownloadTask`，支持原生的后台下载，功能更加强大，使用方式也有了一些改变，不兼容旧版本，请注意新版的使用方法。如果想了解后台下载的细节和注意事项，可以看这篇文章：[iOS原生级别后台下载详解](https://juejin.im/post/5c4ed0b0e51d4511dc730799)

旧版本下载实现基于`URLSessionDataTask`，不支持后台下载，已经移至`dataTask`分支，原则上不再更新，如果不需要后台下载功能，或者不想迁移到新版，可以直接下载`dataTask`分支的源码使用，也可以在`Podfile`里使用以下方式安装：

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'Tiercel', :git => 'https://github.com/Danie1s/Tiercel.git', :branch => 'dataTask'
end
```

## Features:

- [x] 支持原生级别的后台下载
- [x] 支持离线断点续传，App无论crash还是被手动Kill都可以恢复下载
- [x] 拥有精细的任务管理，每个下载任务都可以单独操作和管理
- [x] 支持创建多个下载模块，每个模块互不影响
- [x] 每个下载模块拥有单独的管理者，可以对总任务进行操作和管理
- [x] 内置了下载速度、剩余时间等常见的下载信息
- [x] 链式语法调用
- [x] 支持控制下载任务的最大并发数
- [x] 支持文件校验
- [x] 线程安全

## Requirements

- iOS 8.0+
- Xcode 10.2+
- Swift 5.0+

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

<img src="https://raw.githubusercontent.com/Danie1s/Tiercel/master/Images/1.gif" width="50%" height="50%">

<img src="https://raw.githubusercontent.com/Danie1s/Tiercel/master/Images/2.gif" width="50%" height="50%">

## Usage

### 配置

因为需要支持原生后台下载，所以需要在`AppDelegate` 文件里配置，参考以下做法

```swift
// 在AppDelegate文件里

// 不能使用懒加载
var sessionManager: SessionManager = {
    var configuration = SessionConfiguration()
    configuration.allowsCellularAccess = true
    let manager = SessionManager("default", configuration: configuration, operationQueue: DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue"))
    return manager
}()

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // 必须要保证在这个方法结束前完成SessionManager初始化
    
    return true
}

// 必须实现此方法，并且把identifier对应的completionHandler保存起来
func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {

    if sessionManager.identifier == identifier {
        sessionManager.completionHandler = completionHandler
    }
}
```



### 基本用法

一行代码开启下载

```swift
// 创建下载任务并且开启下载，同时返回可选类型的DownloadTask实例，如果url无效，则返回nil
let task = sessionManager.download("http://api.gfs100.cn/upload/20171219/201712191530562229.mp4")

// 批量创建下载任务并且开启下载，返回有效url对应的任务数组，url需要跟fileNames一一对应
let tasks = sessionManager.multiDownload(URLStrings)
```

如果需要设置回调

```swift
// 回调闭包的参数是Task实例，可以得到所有相关的信息
// 所有闭包都可以选择是否在主线程上执行，由onMainQueue参数控制，如果onMainQueue传false，则会在sessionManager初始化时指定的队列上执行
// progress 闭包：如果任务正在下载，就会触发
// success 闭包：任务已经下载过，或者下载完成，都会触发，这时候task.status == .succeeded
// failure 闭包：只要task.status != .succeeded，就会触发：
//    1. 暂停任务，这时候task.status == .suspended
//    2. 任务下载失败，这时候task.status == .failed
//    3. 取消任务，这时候task.status == .canceled
//    4. 移除任务，这时候task.status == .removed
let task = sessionManager.download("http://api.gfs100.cn/upload/20171219/201712191530562229.mp4")

task?.progress(onMainQueue: true, { (task) in
    let progress = task.progress.fractionCompleted
    print("下载中, 进度：\(progress)")
}).success { (task) in
    print("下载完成")
}.failure { (task) in
    print("下载失败")
}
```

下载任务的管理和操作。**在Tiercel中，url是下载任务的唯一标识，如果需要对下载任务进行操作，则使用SessionManager实例对url进行操作。** 暂停下载、取消下载、移除下载的操作可以添加回调，并且可以选择是否在主线程上执行该回调。

```swift
let URLString = "http://api.gfs100.cn/upload/20171219/201712191530562229.mp4"

// 创建下载任务并且开启下载，同时返回可选类型的DownloadTask实例，如果url无效，则返回nil
let task = sessionManager.download(URLString)
// 根据URLString查找下载任务，返回可选类型的Task实例，如果不存在，则返回nil
let task = sessionManager.fetchTask(URLString)

// 开始下载
// 如果调用suspend暂停了下载，可以调用这个方法继续下载
sessionManager.start(URLString)

// 暂停下载
sessionManager.suspend(URLString)

// 取消下载，没有下载完成的任务会被移除，不保留缓存，已经下载完成的不受影响
sessionManager.cancel(URLString)

// 移除下载，任何状态的任务都会被移除，没有下载完成的缓存文件会被删除，可以选择是否保留已经下载完成的文件
sessionManager.remove(URLString, completely: false)

// 除了可以对单个任务进行操作，TRManager也提供了对所有任务同时操作的API
sessionManager.totalStart()
sessionManager.totalSuspend()
sessionManager.totalCancel()
sessionManager.totalRemove(completely: false)
```



### 后台下载

Tiercel 2 的下载实现基于`URLSessionDownloadTask`，支持原生的后台下载，按照苹果官方文档的要求，SessionManager实例必须在App启动的时候创建，并且在`AppDelegate` 文件里实现以下方法

```swift
// 必须实现此方法，并且把identifier对应的completionHandler保存起来
func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {

    if sessionManager.identifier == identifier {
        sessionManager.completionHandler = completionHandler
    }
}
```

只要使用 Tiercel 开启了下载任务：

- 手动Kill App，任务会暂停，重启App后可以恢复进度，继续下载
- 只要不是手动Kill App，任务都会一直在下载，例如：
  - App退回后台
  - App崩溃或者被系统关闭
  - 重启手机

如果想了解后台下载的细节和注意事项，可以看这篇文章：[iOS原生级别后台下载详解](https://juejin.im/post/5c4ed0b0e51d4511dc730799)



### 文件校验

Tiercel提供了文件校验功能，可以根据需要添加，校验结果在回调的`task.validation`里

```swift

let task = sessionManager.download("http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg")
// 回调闭包可以选择是否在主线程上执行
task?.validateFile(code: "9e2a3650530b563da297c9246acaad5c",
                   type: .md5,
                   onMainQueue: true,
                   { (task) in
    if task.validation == .correct {
        // 文件正确
    } else {
        // 文件错误
    }
})
```

FileChecksumHelper是文件校验的工具类，可以直接使用它对已经存在的文件进行校验

```swift
/// 对文件进行校验，是在子线程进行的
///
/// - Parameters:
///   - filePath: 文件路径
///   - verificationCode: 文件的Hash值
///   - verificationType: Hash类型
///   - completion: 完成回调, 在子线程运行
public class func validateFile(_ filePath: String, 
                               code: String, 
                               type: FileVerificationType, 
                               _ completion: @escaping (Bool) -> ()) {
    
}
```



### SessionManager

SessionManager是下载任务的管理者，管理当前模块所有下载任务

**⚠️⚠️⚠️** 按照苹果官方文档的要求，SessionManager实例必须在App启动的时候创建，即SessionManager的生命周期跟App几乎一致，为方便使用，最好是作为`AppDelegate`的属性，或者是全局变量，具体请参照`Demo`。

```swift
/// 初始化方法
///
/// - Parameters:
///   - identifier: 设置SessionManager实例的标识，区分不同的下载模块，同时为urlSession的标识，原生级别的后台下载必须要有唯一标识
///   - configuration: SessionManager的配置
///   - operationQueue: urlSession的代理回调执行队列，SessionManager中的所有闭包回调如果没有指定在主线程执行，也会在此队列中执行
public init(_ identifier: String,
            configuration: SessionConfiguration,
            operationQueue: DispatchQueue = DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue")) {
    // 实现的代码... 
}
```

SessionManager作为所有下载任务的管理者，也可以设置回调

```swift
// 回调闭包的参数是SessionManager实例，可以得到所有相关的信息
// 所有闭包都可以选择是否在主线程上执行，由onMainQueue参数控制，如果onMainQueue传false，则会在sessionManager初始化时指定的队列上执行
// progress 闭包：只要有一个任务正在下载，就会触发
// success 闭包：只有一种情况会触发：
//    所有任务都下载成功(取消和移除的任务会被移除然后销毁，不再被manager管理) ，这时候manager.status == .succeeded
// failure 闭包：只要manager.status != .succeeded，就会触发：
//    1. 调用全部暂停的方法，或者没有等待运行的任务，也没有正在运行的任务，这时候manager.status == .suspended
//    2. 所有任务都结束，但有一个或者多个是失败的，这时候manager.status == .failed
//    3. 调用全部取消的方法，或者剩下一个任务的时候把这个任务取消，这时候manager.status == .canceled
//    4. 调用全部移除的方法，或者剩下一个任务的时候把这个任务移除，这时候manager.status == .removed
sessionManager.progress(onMainQueue: true, { (manager) in
    let progress = manager.progress.fractionCompleted
    print("downloadManager运行中, 总进度：\(progress)")
    }.success { (manager) in
         print("所有下载任务都成功了")
    }.failure { (manager) in
         if manager.status == .suspended {
            print("所有下载任务都暂停了")
        } else if manager.status == .failed {
            print("存在下载失败的任务")
        } else if manager.status == .canceled {
            print("所有下载任务都取消了")
        } else if manager.status == .removed {
            print("所有下载任务都移除了")
        }
}
```

SessionManager的主要属性

```swift
// 设置内置日志打印等级，如果为none则不打印
public static var logLevel: LogLevel = .detailed
// 是否需要对networkActivityIndicator进行管理
public static var isControlNetworkActivityIndicator = true
// urlSession的代理回调执行队列，SessionManager中的所有闭包回调如果没有指定在主线程执行，也会在此队列中执行
public let operationQueue: DispatchQueue
// SessionManager的状态
public var status: Status = .waiting
// SessionManager的缓存管理实例
public var cache: Cache
// SessionManager的标识，区分不同的下载模块
public let identifier: String
// SessionManager的进度
public var progress: Progress
// SessionManager的配置，可以设置请求超时时间，最大并发数，是否允许蜂窝网络下载
public var configuration = SessionConfiguration()
// 所有下载中的任务加起来的总速度
public private(set) var speed: Int64 = 0
// 所有下载中的任务需要的剩余时间
public private(set) var timeRemaining: Int64 = 0
// SessionManager管理的下载任务，取消和移除的任务会被销毁，但操作是异步的，在回调闭包里面获取才能保证正确
public var tasks: [Task] = []
```



### SessionConfiguration

SessionConfiguration是Tiercel中配置SessionManager的结构体，可配置属性如下：

```swift
// 请求超时时间
public var timeoutIntervalForRequest = 30.0

// 最大并发数
// 支持后台下载的任务，系统会进行最大并发数限制
// 在iOS 11及以上是6，iOS 11以下是3
public var maxConcurrentTasksLimit

// 是否允许蜂窝网络下载
public var allowsCellularAccess = false
```

更改SessionManager的配置

```swift
// 无论是否有下载任务正在运行，都可以更改SessionManager配置
// 如果只是更改某一项，可以直接对SessionManager属性设置
sessionManager.configuration.allowsCellularAccess = true

// 如果是需要更改多项，需要重新创建SessionConfiguration，再进行赋值
let configuration = SessionConfiguration()
configuration.allowsCellularAccess = true
configuration.maxConcurrentTasksLimit = 2
configuration.timeoutIntervalForRequest = 60

sessionManager.configuration = configuration
```

**注意：建议在SessionManager初始化的时候传入已经修改好的`SessionConfiguration`实例，参考Demo。Tiercel也支持在任务下载中修改配置，但是不建议修改`configuration`后马上开启任务下载，即不要在同一个代码块里修改`configuration`后开启任务下载，这样很容易造成错误。**

```swift
// 不要这样操作
sessionManager.configuration.allowsCellularAccess = true
let task = sessionManager.download("http://api.gfs100.cn/upload/20171219/201712191530562229.mp4")
```

**如果实在需要进行这种操作，请修改`configuration`后，设置1秒以上的延迟再开启任务下载。**

```swift
// 如果实在需要，请延迟开启任务
sessionManager.configuration.allowsCellularAccess = true
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    let task = sessionManager.download("http://api.gfs100.cn/upload/20171219/201712191530562229.mp4")
}
```



### DownloadTask

DownloadTask是Tiercel中的下载任务类，继承自Task。**在Tiercel中，url是下载任务的唯一标识，url代表着任务，如果需要对下载任务进行操作，则使用SessionManager实例对url进行操作。** 所以DownloadTask实例都是由SessionManager实例创建，单独创建没有意义。

主要属性

```swift
// 保存到沙盒的下载文件的文件名，如果在下载的时候没有设置，则默认为url的md5加上文件扩展名
public internal(set) var fileName: String
// 下载任务对应的url
public let url: URL
// 下载任务的状态
public var status: Status
// 下载文件的校验状态
public var validation: Validation
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
// 下载文件路径
public var filePath: String
// 下载文件的扩展名
public var pathExtension: String?
```

对下载任务操作，必须通过SessionManager实例进行，不能用DownloadTask实例直接操作

- 开启
- 暂停
- 取消，没有完成的任务从SessionManager实例中的tasks中移除，不保留缓存，已经下载完成的任务不受影响
- 移除，已经完成的任务也会被移除，没有下载完成的缓存文件会被删除，已经下载完成的文件可以选择是否保留

**注意：对下载中的任务进行暂停、取消和移除操作，结果是异步回调的，在回调闭包里面获取状态才能保证正确，并且可以选择是否在主线程上执行该回调，由onMainQueue参数控制，如果onMainQueue传false，则会在sessionManager初始化时指定的队列上执行**



### Cache

Cache是Tiercel中负责管理缓存下载任务信息和下载文件的类。Cache实例一般作为SessionManager实例的属性来使用。

```swift
/// 初始化方法
///
/// - Parameters:
///   - name: 不同的name，代表不同的下载模块，对应的文件放在不同的地方，对应SessionManager创建时传入的identifier
public init(_ name: String) {
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




## License

Tiercel is available under the MIT license. See the LICENSE file for more info.


