# iOS原生级别后台下载详解

- [初衷](#初衷)
- [理想与现实](#理想与现实)
- [勿忘初心](#勿忘初心)
- [后台下载](#后台下载)
  - [URLSession](#urlsession)
  - [URLSessionDownloadTask](#urlsessiondownloadtask)
  - [断点续传](#断点续传)
  - [ResumeData](#resumedata)
    - [ResumeData的结构](#resumedata的结构)
    - [ResumeData的Bug](#resumedata的bug)
  - [具体表现](#具体表现)
    - [下载过程中](#下载过程中)
    - [下载完成](#下载完成)
    - [下载错误](#下载错误)
  - [重定向](#重定向)
  - [最大并发数](#最大并发数)
  - [前后台切换](#前后台切换)
  - [注意事项](#注意事项)
- [最后](#最后)



## 初衷

很久以前，我发现了一个将要面对的问题：

> 怎样才能并发地下载一堆文件，并且全部下载完成后再执行其他操作？

当然，这个问题其实很简单，解决方案也有很多。但我第一时间想到的是，目前是否存一个具有任务组概念，非常权威，非常流行、稳定可靠，并且是用Swift写的，Github上star非常多的下载框架？如果存在这样的轮子，我就打算把它作为项目里专用的下载模块。很可惜，下载框架很多，也有很多这方面的文章和Demo，但是像`AFNetworking`、`SDWebImage`这种著名权威，star非常多的，真的一个都没有，而且有一些还是用`NSURLConnection`实现的，用Swift写的就更少了，这让我有了打算自己实现一个的想法。

## 理想与现实

轮子这种东西，既然要自己撸，就不能随便，而且下载框架这方面也没权威著名的，所以一开始我打算满足自己需求的同时，尽量能做更多的事情，争取以后负责的项目都可以用得上。首先要满足的就是后台下载，众所周知iOS的App在后台是暂停的，那么要实现后台下载，就需要按照苹果的规定，使用`URLSessionDownloadTask`。

网上一搜就有大量的相关文章和Demo，然后我就开始愉快地撸代码。结果撸到一半发现，真正实现起来并且没有网上的文章说得那么简单，测试发现开源的轮子和Demo也有很多地方有Bug，不完善，或者说没有完整地实现后台下载。于是只能靠自己继续深入的研究，但当时确实没有这方面研究地比较透彻文章，而时间方面也不允许，必须得尽快撸个轮子出来使用。所以最后我妥协了，我用了一个比较容易处理的办法，改成用`URLSessionDataTask`实现，虽然不是原生支持后台下载，但我觉得总有一些邪门歪道可以实现的，最后我写出了`Tiercel`，一个对现实妥协的下载框架，不过已经满足了我的需求。

## 勿忘初心

因为其实我并没有遇到后台下载硬性需求，所以我一直没有寻找其他办法去实现，而且我觉得如果要做，就必须使用`URLSessionDownloadTask`，实现原生级别的后台下载。随着时间的推移，我心里一直都觉得没有完成当初的想法是一个极大的遗憾，于是我最后下定决心，打算把iOS的后台下载研究透彻。

终于，完美支持原生后台下载的[Tiercel 2](https://github.com/Danie1s/Tiercel)诞生了。下面我将详细讲解后台下载的实现和注意事项，希望能够帮助有需要的人。

## 后台下载

关于后台下载，其实苹果有提供文档---[Downloading Files in the Background](https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background)，但实现起来要面对的问题比文档说的要多得多。

### URLSession

首先，如果需要实现后台下载，就必须创建`Background Sessions`

```swift
private lazy var urlSession: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: "com.Daniels.Tiercel")
    config.isDiscretionary = true
    config.sessionSendsLaunchEvents = true
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
}()
```

 通过这种方式创建的`URLSession`，其实是`__NSURLBackgroundSession`：

- 必须使用`background(withIdentifier:)`方法创建`URLSessionConfiguration`，其中这个`identifier`必须是固定的，而且为了避免跟其他App冲突，建议这个`identifier`跟App的`Bundle ID`相关
- 创建`URLSession`的时候，必须传入`delegate`
- 必须在App启动的时候创建`Background Sessions`，即它的生命周期跟App几乎一致，为方便使用，最好是作为`AppDelegate`的属性，或者是全局变量，原因在后面会有详细说明。

### URLSessionDownloadTask

只有`URLSessionDownloadTask`才支持后台下载

```swift
let downloadTask = urlSession.downloadTask(with: url)
downloadTask.resume()
```

通过`Background Sessions`创建出来的downloadTask，其实是`__NSCFBackgroundDownloadTask`

到目前为止，已经创建并且开启了支持后台下载的任务，但真正的难题，现在才开始

### 断点续传

苹果的官方文档----[Pausing and Resuming Downloads](https://developer.apple.com/documentation/foundation/url_loading_system/pausing_and_resuming_downloads)

`URLSessionDownloadTask` 的断点续传依靠的是`resumeData`

```swift
// 取消时保存resumeData
downloadTask.cancel { resumeDataOrNil in
    guard let resumeData = resumeDataOrNil else { return }
    self.resumeData = resumeData
}

// 或者是在session delegate 的 urlSession(_:task:didCompleteWithError:) 方法里面获取
func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error,
    	let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
        self.resumeData = resumeData
    } 
}

// 用resumeData恢复下载
guard let resumeData = resumeData else {
    // inform the user the download can't be resumed
    return
}
let downloadTask = urlSession.downloadTask(withResumeData: resumeData)
downloadTask.resume()
```

正常情况下，这样就已经可以恢复下载任务，但实际上并没有那么顺利，`resumeData`就存在各种各样的问题。

### ResumeData

在iOS中，这个`resumeData`简直就是奇葩的存在，如果你有去研究过它，你会觉得不可思议，因为这个东西一直在变，而且经常有Bug，似乎苹果就是不想我们对它进行操作。

#### ResumeData的结构

在iOS12之前，直接把`resumeData`保存为`resumeData.plist`到本地，可以看出里面的结构。

- 在iOS 8，resumeData的key：

```swift
// url
NSURLSessionDownloadURL
// 已经接受的数据大小
NSURLSessionResumeBytesReceived
// currentRequest
NSURLSessionResumeCurrentRequest
// Etag，下载文件的唯一标识
NSURLSessionResumeEntityTag
// 已经下载的缓存文件路径
NSURLSessionResumeInfoLocalPath
// resumeData版本
NSURLSessionResumeInfoVersion = 1
// originalRequest
NSURLSessionResumeOriginalRequest

NSURLSessionResumeServerDownloadDate
```

- 在iOS 9 - iOS 10，改动如下:
  - `NSURLSessionResumeInfoVersion = 2`，`resumeData`版本升级
  - `NSURLSessionResumeInfoLocalPath`改成`NSURLSessionResumeInfoTempFileName`，缓存文件路径变成了缓存文件名
- 在iOS 11，改动如下：
  - `NSURLSessionResumeInfoVersion = 4`，`resumeData`版本再次升级，应该是直接跳过3了
  - 如果是多次对downloadTask进行 `取消 - 恢复` 操作，生成的`resumeData`会多出一个key为`NSURLSessionResumeByteRange`的键值对
- 在iOS 12，`resumeData`编码方式改变，需要用`NSKeyedUnarchiver`来解码，结构没有改变

了解`resumeData`结构对解决它引起的Bug，实现离线断点续传，起到关键作用。

#### ResumeData的Bug

`resumeData`不但结构一直变化，而且也一直存在各种各样的Bug

- 在iOS 10.0 - iOS 10.1：
  - Bug：使用系统生成的`resumeData`无法直接恢复下载，原因是`currentRequest`和`originalRequest` 的` NSKeyArchived`编码异常，iOS 10.2及以上会修复这个问题。
  - 解决方法：获取到`resumeData`后，需要对它进行修正，使用修正后的`resumeData`创建downloadTask，再对downloadTask的`currentRequest`和`originalRequest`赋值，[Stack Overflow](https://stackoverflow.com/questions/39346231/resume-nsurlsession-on-ios10/39347461#39347461)上面有具体说明。
- 在iOS 11.0 - iOS 11.2：
  - Bug：由于多次对downloadTask进行 `取消 - 恢复` 操作，生成的`resumeData`会多出一个key为`NSURLSessionResumeByteRange`的键值对，所以会导致直接下载成功（实际上没有），下载的文件大小直接变成0，iOS 11.3及以上会修复这个问题。
  - 解决方法：把key为`NSURLSessionResumeByteRange`的键值对删除。
- 在iOS 10.3 - iOS 12.1：
  - Bug：从iOS 10.3开始，只要对downloadTask进行 `取消 - 恢复` 操作，使用生成的`resumeData`创建downloadTask，它的`originalRequest`为nil，到目前最新的系统版本（iOS 12.1）仍然一样，虽然不会影响文件的下载，但会影响到下载任务的管理。
  - 解决方法：使用`currentRequest`匹配任务，这里涉及到一个重定向问题，后面会有详细说明。

以上是目前总结出的`resumeData`在不同的系统版本出现的改动和Bug，解决的具体代码可以参考`Tiercel`。

### 具体表现

支持后台下载的downloadTask已经创建，`resumeData`的问题也已经解决，现在已经可以愉快地开启和恢复下载了。接下来要面对的是，这个downloadTask的具体表现，这也是实现一个下载框架最重要的环节。

#### 下载过程中

为了测试downloadTask在不同情况下的表现，花费了大量的时间和精力，具体如下：

|        操作         |                             创建                             |                            运行中                            |                       暂停（suspend）                        |             取消（cancelByProducingResumeData）              |                        取消（cancel）                        |
| :-----------------: | :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: |
|   立即产生的效果    |            在App沙盒的caches文件夹里面创建tmp文件            |          把下载的数据写入caches文件夹里面的tmp文件           |             caches文件夹里面的tmp文件不会被移动              | caches文件夹里面的tmp文件会被移动到Tmp文件夹，会调用didCompleteWithError | caches文件夹里面的tmp文件会被删除，会调用didCompleteWithError |
|      进入后台       |                         自动开启下载                         |                           继续下载                           |                       没有发生任何事情                       |                       没有发生任何事情                       |                       没有发生任何事情                       |
|    手动kill App     | 关闭的时候caches文件夹里面的tmp文件会被删除，重新打开app后创建相同identifier的session，会调用didCompleteWithError（等于调用了cancel） | 关闭的时候下载停止了，caches文件夹里面的tmp文件不会被移动，重新打开app后创建相同identifier的session，tmp文件会被移动到Tmp文件夹，会调用didCompleteWithError（等于调用了cancelByProducingResumeData） | 关闭的时候caches文件夹里面的tmp文件不会被移动，重新打开app后创建相同identifier的session，tmp文件会被移动到Tmp文件夹，会调用didCompleteWithError（等于调用了cancelByProducingResumeData） |                       没有发生任何事情                       |                       没有发生任何事情                       |
| crash或者被系统关闭 | 自动开启下载，caches文件夹里面的tmp文件不会被移动，重新打开app后，不管是否有创建相同identifier的session，都会继续下载（保持下载状态） | 继续下载，caches文件夹里面的tmp文件不会被移动，重新打开app后，不管是否有创建相同identifier的session，都会继续下载（保持下载状态） | caches文件夹里面的tmp文件不会被移动，重新打开app后创建相同identifier的session，不会调用didCompleteWithError，session里面还保存着task，此时task还是暂停状态，可以恢复下载 |                       没有发生任何事情                       |                       没有发生任何事情                       |

支持后台下载的`URLSessionDownloadTask`，真实类型是`__NSCFBackgroundDownloadTask`，具体表现跟普通的有很大的差别，根据上面的表格和苹果官方文档：

- 当创建了`Background Sessions`，系统会把它的`identifier`记录起来，只要App重新启动后，创建对应的`Background Sessions`，它的代理方法也会继续被调用
- 如果是任务被`session`管理，则下载中的tmp格式缓存文件会在沙盒的caches文件夹里；如果不被`session`管理，且可以恢复，则缓存文件会被移动到Tmp文件夹里；如果不被`session`管理，且不可以恢复，则缓存文件会被删除。即：
  - downloadTask运行中和调用`suspend`方法，缓存文件会在沙盒的caches文件夹里
  - 调用`cancelByProducingResumeData`方法，则缓存文件会在Tmp文件夹里
  - 调用`cancel`方法，缓存文件会被删除
- 手动Kill App会调用了`cancelByProducingResumeData`或者`cancel`方法
  - 在iOS 8 上，手动kill会马上调用`cancelByProducingResumeData`或者`cancel`方法，然后会调用`urlSession(_:task:didCompleteWithError:)`代理方法
  - 在iOS 9 - iOS 12 上，手动kill会马上停止下载，当App重新启动后，创建对应的`Background Sessions`后，才会调用`cancelByProducingResumeData`或者`cancel`方法，然后会调用`urlSession(_:task:didCompleteWithError:)`代理方法
- 进入后台、crash或者被系统关闭，系统会有另外一条进程对下载任务进行管理，没有开启的任务会自动开启，已经开启的会保持原来的状态（继续运行或者暂停），当App重新启动后，创建对应的`Background Sessions`，可以使用`session.getTasksWithCompletionHandler(_:)`方法来获取任务，session的代理方法也会继续被调用（如果需要）
- 最令人意外的是，只要没有手动Kill App，就算重启手机，重启完成后原来在运行的下载任务还是会继续下载，实在牛逼

既然已经总结出规律，那么处理起来就简单了：

- 在App启动的时候创建`Background Sessions`
- 使用`cancelByProducingResumeData`方法暂停任务，保证可以恢复任务
  - 其实也可以使用`suspend`方法，但在iOS 10.0 - iOS 10.1 中暂停后如果不马上恢复任务，会无法恢复任务，这又是一个Bug，所以不建议
- 手动Kill App会调用了`cancelByProducingResumeData`或者`cancel`，最后会调用`urlSession(_:task:didCompleteWithError:)`代理方法，可以在这里做集中处理，管理downloadTask，把`resumeData`保存起来
- 进入后台、crash或者被系统关闭，不影响原来任务的状态，当App重新启动后，创建对应的`Background Sessions`后，使用`session.getTasksWithCompletionHandler(_:)`来获取任务

#### 下载完成

由于支持后台下载，下载任务完成时，App有可能处于不同状态，所以还要了解对应的表现：

- 在前台：跟普通的downloadTask一样，调用相关的session代理方法
- 在后台：当`Background Sessions`里面所有的任务（注意是所有任务，不单单是下载任务）都完成后，会调用`AppDelegate`的`application(_:handleEventsForBackgroundURLSession:completionHandler:)`方法，激活App，然后跟在前台时一样，调用相关的session代理方法，最后再调用`urlSessionDidFinishEvents(forBackgroundURLSession:) `方法
- crash或者App被系统关闭：当`Background Sessions`里面所有的任务（注意是所有任务，不单单是下载任务）都完成后，会自动启动App，调用`AppDelegate`的`application(_:didFinishLaunchingWithOptions:)`方法，然后调用`application(_:handleEventsForBackgroundURLSession:completionHandler:)`方法，当创建了对应的`Background Sessions`后，才会跟在前台时一样，调用相关的session代理方法，最后再调用`urlSessionDidFinishEvents(forBackgroundURLSession:) `方法
- crash或者App被系统关闭，打开App保持前台，当所有的任务都完成后才创建对应的`Background Sessions`：没有创建session时，只会调用`AppDelegate`的`application(_:handleEventsForBackgroundURLSession:completionHandler:)`方法，当创建了对应的`Background Sessions`后，才会跟在前台时一样，调用相关的session代理方法，最后再调用`urlSessionDidFinishEvents(forBackgroundURLSession:) `方法
- crash或者App被系统关闭，打开App，创建对应的`Background Sessions`后所有任务才完成：跟在前台的时候一样

总结：

- 只要不在前台，当所有任务完成后会调用`AppDelegate`的`application(_:handleEventsForBackgroundURLSession:completionHandler:)`方法
- 只有创建了对应`Background Sessions`，才会调用对应的session代理方法，如果不在前台，还会调用`urlSessionDidFinishEvents(forBackgroundURLSession:) `

具体处理方式：

首先就是`Background Sessions`的创建时机，前面说过：

> 必须在App启动的时候创建`URLSession`，即它的生命周期跟App几乎一致，为方便使用，最好是作为`AppDelegate`的属性，或者是全局变量。

原因：下载任务有可能在App处于不同状态时完成，所以需要保证App启动的时候，`Background Sessions`也已经创建，这样才能使它的代理方法正确的调用，并且方便接下来的操作。

根据下载任务完成时的表现，结合苹果官方文档：

```swift
// 必须在AppDelegate中，实现这个方法
//
//   - identifier: 对应Background Sessions的identifier
//   - completionHandler: 需要保存起来
func application(_ application: UIApplication,
                 handleEventsForBackgroundURLSession identifier: String,
                 completionHandler: @escaping () -> Void) {
    	if identifier == urlSession.configuration.identifier ?? "" {
            // 这里用作为AppDelegate的属性，保存completionHandler
            backgroundCompletionHandler = completionHandler
	    }
}
```

然后要在session的代理方法里调用`completionHandler`，它的作用请看：[application(_:handleEventsForBackgroundURLSession:completionHandler:)](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622941-application)

```swift
// 必须实现这个方法，并且在主线程调用completionHandler
func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
        let backgroundCompletionHandler = appDelegate.backgroundCompletionHandler else { return }
        
    DispatchQueue.main.async {
        // 上面保存的completionHandler
        backgroundCompletionHandler()
    }
}
```

至此，下载完成的情况也处理完毕

#### 下载错误

支持后台下载的downloadTask失败的时候，在`urlSession(_:task:didCompleteWithError:)`方法里面的`(error as NSError).userInfo`可能会出现一个key为`NSURLErrorBackgroundTaskCancelledReasonKey`的键值对，由此可以获得只有后台下载任务失败时才有相关的信息，具体请看：[Background Task Cancellation](https://developer.apple.com/documentation/foundation/urlsession/1508626-background_task_cancellation)

```swift
func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error {
        let backgroundTaskCancelledReason = (error as NSError).userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int
    }
}
```

### 重定向

支持后台下载的downloadTask，由于App有可能处于后台，或者crash，或者被系统关闭，只有当`Background Sessions`所有任务完成时，才会激活或者启动，所以无法处理处理重定向的情况。

苹果官方文档指出：

> Redirects are always followed. As a result, even if you have implemented [`urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)`](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/1411626-urlsession), it is *not* called.

意思是始终遵从重定向，并且不会调用`urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)`方法。

前面有提到downloadTask的`originalRequest`有可能为nil，只能用`currentRequest`来匹配任务进行管理，但`currentRequest`也有可能因为重定向而发生改变，而重定向的代理方法又不会调用，所以只能用KVO来观察`currentRequest`，这样就可以获取到最新的`currentRequest`

### 最大并发数

`URLSessionConfiguration`里有个`httpMaximumConnectionsPerHost`的属性，它的作用是控制同一个host同时连接的数量，苹果的文档显示，默认在macOS里是6，在iOS里是4。单从字面上来看它的效果应该是：如果设置为N，则同一个host最多有N个任务并发下载，其他任务在等待，而不同host的任务不受这个值影响。但是实际上又有很多需要注意的地方。

- 没有资料显示它的最大值是多少，经测试，设置为1000000都没有问题，但是如果设置为Int.Max，则会出问题，对于大多数URL都是无法下载（应该跟目标url的服务器有关）；如果设置为小于1，对于大多数URL都无法下载
- 当使用`URLSessionConfiguration.default`来创建一个`URLSession`时，无论在真机还是模拟器上
  - `httpMaximumConnectionsPerHost`设置为10000，无论是否同一个host，都可以有多个任务（测试过180多个）并发下载
  - `httpMaximumConnectionsPerHost`设置为1，对于同一个host只能同时有一个任务在下载，不同host可以有多个任务并发下载
- 当使用`URLSessionConfiguration.background(withIdentifier:)`来创建一个支持后台下载的`URLSession`
  - 在模拟器上
    - `httpMaximumConnectionsPerHost`设置为10000，无论是否同一个host，都可以有多个任务（测试过180多个）并发下载
    - `httpMaximumConnectionsPerHost`设置为1，对于同一个host只能同时有一个任务在下载，不同host可以有多个任务并发下载
  - 在真机上
    - `httpMaximumConnectionsPerHost`设置为10000，无论是否同一个host，并发下载的任务数都有限制（目前最大是6）
    - `httpMaximumConnectionsPerHost`设置为1，对于同一个host只能同时有一个任务在下载，不同host并发下载的任务数有限制（目前最大是6）
    - 即使使用多个`URLSession`开启下载，可以并发下载的任务数量也不会增加
    - 以下是部分系统并发数的限制
      - iOS 9 iPhone SE上是3
      - iOS 10.3.3 iPhone 5上是3 
      - iOS 11.2.5 iPhone 7Plus上是6
      - iOS 12.1.2 iPhone 6s上是6
      - iOS 12.2 iPhone XS Max上是6

从以上几点可以得出结论，由于支持后台下载的`URLSession`的特性，系统会限制并发任务的数量，以减少资源的开销。同时对于不同的host，就算`httpMaximumConnectionsPerHost`设置为1，也会有多个任务并发下载，所以不能使用`httpMaximumConnectionsPerHost`来控制下载任务的并发数。[Tiercel 2](https://github.com/Danie1s/Tiercel)是通过判断正在下载的任务数从而进行并发的控制。

### 前后台切换

在downloadTask运行中，App进行前后台切换，会导致`urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)`方法不调用

- 在iOS 12 - iOS 12.1，iPhone
  8 以下的真机中，App进入后台再回到前台，进度的代理方法不调用，当再次进入后台的时候，有短暂的时间会调用进度的代理方法
- 在iOS 12.1，iPhone XS的模拟器中，多次进行前台后台切换，偶尔会出现进度的代理方法不调用，真机目测不会
- 在iOS 11.2.2，iPhone 6真机中，进行前台后台切换，会出现进度的代理方法不调用，多次切换则有机会恢复

以上是我测试了一些机型后发现的问题，没有覆盖全部机型，更多的情况可自行测试

解决办法：使用通知监听`UIApplication.didBecomeActiveNotification`，延迟0.1秒调用`suspend`方法，再调用`resume`方法

### 注意事项

- 沙盒路径：用Xcode运行和停止项目，可以达到App crash的效果，但是无论是用真机还是模拟器，每用Xcode运行一次，都会改变沙盒路径，这会导致系统对downloadTask相关的文件操作失败，在某些情况系统记录的是上次的项目沙盒路径，最终导致出现无法开启任务下载、找不到文件夹等错误。我刚开始就是遇到这种情况，我并不知道是这个原因，所以觉得无法预测，也无法解决。各位在开发测试的时候，一定要注意。
- 真机与模拟器：由于iOS后台下载的特性和注意事项实在太多，而且不同的iOS版本之间还存在一定的差别，所以使用模拟器进行开发和测试是一种很方便的选择。但是有些特性在真机和模拟器上表现又会不一样，例如在模拟器上下载任务的并发数是很大的，而在真机上则很小（在iOS 12上是6），所以一定要在真机上进行测试或者校验，以真机的结果为准。
- 缓存文件：前面说了恢复下载依靠的是`resumeData`，其实还需要对应的缓存文件，在`resumeData`里可以得到缓存文件的文件名（在iOS 8获得的是缓存文件路径），因为之前推荐使用`cancelByProducingResumeData`方法暂停任务，那么缓存文件会被移动到沙盒的Tmp文件夹，这个文件夹的数据在某些时候会被系统自动清理掉，所以为了以防万一，最好是额外保存一份。

## 最后

如果大家有耐心把前面的内容认真看完，那么恭喜你们，你们已经了解了iOS后台下载的所有特性和注意事项，同时你们也已经明白为什么目前没有一款完整实现后台下载的开源框架，因为Bug和要处理的情况实在是太多。这篇文章只是我个人的一些总结，可能会存在没有发现问题或者细节，如果有新的发现，请给我留言。

目前[Tiercel 2](https://github.com/Danie1s/Tiercel)已经发布，完美地支持后台下载，还加入了文件校验等功能，需要了解更多的细节，可以参考代码，欢迎各位使用，测试，提交Bug和建议。



