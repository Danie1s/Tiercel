[TOC]







# iOS原生后台下载详解

## 初衷

很久以前，我发现了一个可能要面对的问题：

> 怎么才能并发地下载一堆文件，并且全部下载完成后再执行其他操作？

当然，这个问题其实很简单，解决方案也有很多。但是，我第一时间想到的是，目前是否存一个具有任务组概念，非常权威，非常流行、稳定可靠，并且是用Swift写的，Github上Star非常多的下载框架？我考虑的是如果存在这样的轮子，我就打算把它作为项目里专用的下载模块。很可惜，下载框架很多，也有很多这方面的demo和文章，但是像`AFNetworking`、`SDWebImage`这种著名，Star非常多的，真的一个都没有，并且有一些还是用`NSURLConnection`实现的，用Swift写的就更少了，这让我有了打算自己撸一个的想法。

## 理想与现实

轮子这种东西，既然要自己撸，就不能随便，而且下载框架这方面也没权威著名的，所以一开始我打算满足自己需求的同时，尽量能做更多的事情，争取以后负责的项目都可以用得上。首先要满足的就是后台下载，众所周知iOS的App在后台是暂停的，那么要实现后台下载，就需要按照苹果的规定，使用`URLSessionDownloadTask`。

网上一搜就有大量的相关文章和`demo`，然后我就开始愉快地撸代码。结果撸到一半发现，真正实现起来并且没有网上的文章说得那么简单，测试发现开源的轮子和`demo`也有很多地方有Bug，不完善，或者说没有完整地实现后台下载。于是继续深入的研究，但当时确实没有这方面研究地比较透彻文章，而自己好像也没有时间继续研究下去了，必须得尽快撸个轮子出来使用。所以最后我妥协了，我用了一个比较容易处理的办法，改成用`URLSessionDataTask`实现，虽然不是原生支持后台下载，但我觉得总有一些邪门歪道可以实现的，最后我写出了`Tiercel`，一个对现实妥协的下载框架，用`URLSessionDataTask`实现起来简单了很多，也满足我的需求，下载框架，除了不支持后台下载。

## 勿忘初心

因为其实我并没有遇到后台下载硬性需求，所以我一直没有去寻找其他办法实现，而且如果要做，就必须用`URLSessionDownloadTask`去实现原生级别的后台下载。但我一直都觉得没有实现当初的想法是一个极大的遗憾，于是我最后下定决心，打算把iOS的后台下载研究透彻。终于，完美支持原生后台下载的`Tiercel 2`诞生了。下面我将详细后台下载的实现和注意事项，希望能够帮助有需要的人。

## 后台下载

苹果官方的文档---[Downloading Files in the Background](https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background)

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

- 必须使用`background(withIdentifier:)`创建`URLSessionConfiguration`，其中这个`identifier`必须是固定的，而且为了避免跟其他App冲突，建议这个`identifier`跟App的`bundle id`相关
- 创建`URLSession`的时候，必须传入`delegate`
- 必须在App启动的时候创建`URLSession`，即它的生命周期跟App几乎一致，为方便使用，最好是作为`AppDelegate`的属性，或者是全局变量，原因在后面会有详细说明。

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
    guard let error = error else {
        // Handle success case.
        return
    }
    let userInfo = (error as NSError).userInfo
    if let resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
        self.resumeData = resumeData
    } 
    // Perform any other error handling.
}

// 用resumeData恢复下载
guard let resumeData = resumeData else {
    // inform the user the download can't be resumed
    return
}
let downloadTask = urlSession.downloadTask(withResumeData: resumeData)
downloadTask.resume()
self.downloadTask = downloadTask
```

正常情况下，这样就已经可以恢复下载任务，可是现实很残酷，`resumeData`就是需要解决的第一个大坑。

### ResumeData

在iOS中，这个`resumeData`简直就是奇葩的存在，如果你有去研究过它，你会觉得不可思议，因为这个东西一直在变，而且经常有Bug，似乎苹果就是不想让我们去操作它。

#### ResumeData 的结构

在iOS12之前，直接把`resumeData`保存为`resumeData.plist`到本地，可以看出里面的结构。

在iOS 8，resumeData的key：

```swift
// url
NSURLSessionDownloadURL
// 已经接受的数据大小
NSURLSessionResumeBytesReceived
// currentRequest
NSURLSessionResumeCurrentRequest
// tag
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

#### ResumeData 的Bug

`resumeData`不但结构一直变化，而且也一直存在各种各样的Bug

- 在iOS 10.0 - iOS 10.1：
  - Bug：系统生成的`resumeData`无法直接恢复下载，原因是`currentRequest`和`originalRequest` ` NSKeyArchived`编码异常，iOS 10.2及以上会修复这个问题。
  - 解决方法：获取到`resumeData`后，需要对它进行修正，使用修正后的`resumeData`创建downloadTask，再对downloadTask的`currentRequest`和`originalRequest`赋值，[Stack Overflow](https://stackoverflow.com/questions/39346231/resume-nsurlsession-on-ios10/39347461#39347461)上面有具体说明。
- 在iOS 11.0 - iOS 11.2：
  - Bug：由于多次对downloadTask进行 `取消 - 恢复` 操作，生成的`resumeData`会多出一个key为`NSURLSessionResumeByteRange`的键值对，所以会导致直接下载成功（实际上还没下载完成），下载的文件大小直接变成0，iOS 11.3及以上会修复这个问题。
  - 解决方法：把key为`NSURLSessionResumeByteRange`的键值对删除即可
- 在iOS 10.3 - iOS 12.1：
  - Bug：从iOS 10.3开始，只要对downloadTask进行 `取消 - 恢复` 操作，使用生成的`resumeData`创建downloadTask，它的`originalRequest`为nil，到目前最新的系统版本（iOS 12.1）仍然一样，虽然不会影响文件的下载，但会影响到下载任务的管理。
  - 解决方法：使用`currentRequest`匹配任务，这里涉及到一个重定向问题，后面会有详细说明。

以上是目前总结出的`resumeData`在不同的系统版本出现的改动和Bug，具体代码可以参考`Tiercel`。

### 具体表现

支持后台下载的downloadTask已经创建，`resumeData`的问题也已经解决，现在已经可以愉快地开启和恢复下载了，但接下来要面对的是，这个downloadTask的具体表现，这也是实现一个下载框架最重要的环节。

#### 下载过程中

测试downloadTask在不同情况下的表现，花费了大量的时间和精力，具体如下：

|             操作              |                             创建                             |                            运行中                            |                       暂停（suspend）                        |             取消（cancelByProducingResumeData）              |                        取消（cancel）                        |
| :---------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: |
|        立即产生的效果         |            在App沙盒的caches文件夹里面创建tmp文件            |          把下载的数据写入caches文件夹里面的tmp文件           |             caches文件夹里面的tmp文件不会被移动              | caches文件夹里面的tmp文件会被移动到Tmp文件夹，会调用didCompleteWithError | caches文件夹里面的tmp文件会被删除，会调用didCompleteWithError |
|           进入后台            |                         自动开启下载                         |                           继续下载                           |                       没有发生任何事情                       |                       没有发生任何事情                       |                       没有发生任何事情                       |
|         手动kill App          | 关闭的时候caches文件夹里面的tmp文件会被删除，重新打开app后创建相同identifier的session，会调用didCompleteWithError（等于调用了cancel） | 关闭的时候下载停止了，caches文件夹里面的tmp文件不会被移动，重新打开app后创建相同identifier的session，tmp文件会被移动到Tmp文件夹，会调用didCompleteWithError（等于调用了cancelByProducingResumeData） | 关闭的时候caches文件夹里面的tmp文件不会被移动，重新打开app后创建相同identifier的session，tmp文件会被移动到Tmp文件夹，会调用didCompleteWithError（等于调用了cancelByProducingResumeData） |                       没有发生任何事情                       |                       没有发生任何事情                       |
| 代码引起的crash或者被系统关闭 | 继续下载，caches文件夹里面的tmp文件不会被移动，重新打开app后，不管是否有创建相同identifier的session，都会继续下载（保持下载状态） | 继续下载，caches文件夹里面的tmp文件不会被移动，重新打开app后，不管是否有创建相同identifier的session，都会继续下载（保持下载状态） | caches文件夹里面的tmp文件不会被移动，不会调用didCompleteWithError，session里面还保存着task，此时task还是暂停状态，可以恢复下载 |                       没有发生任何事情                       |                       没有发生任何事情                       |

支持后台下载的`URLSessionDownloadTask`，真实类型是`__NSCFBackgroundDownloadTask`，具体表现跟普通的有很大的区别，根据上面的表格和苹果官方文档：

- 当创建了`Background Sessions`，系统会把它的`identifier`记录起来，只要App重新启动后，创建对应的`Background Sessions`，它的代理方法也会继续被调用
- 如果是任务被`session`管理，则下载中的tmp格式缓存文件会在沙盒的caches文件夹里；如果不被`session`管理，且可以恢复，则缓存文件会在Tmp文件夹里；如果不被`session`管理，且不可以恢复，则缓存文件会被删除。即：
  - downloadTask运行中和调用`suspend`方法，缓存文件会在沙盒的caches文件夹里
  - 调用`cancelByProducingResumeData`方法，则缓存文件会在Tmp文件夹里
  - 调用`cancel`方法，缓存文件会被删除
- 手动Kill App会调用了`cancelByProducingResumeData`或者`cancel`方法
  - 在iOS 8 上，手动kill会马上调用`cancelByProducingResumeData`或者`cancel`方法，然后会调用`didCompleteWithError`代理方法
  - 在iOS 9 - iOS 12 上，手动kill会马上停止下载，当App重新启动后，创建对应的`Background Sessions`后，才会调用`cancelByProducingResumeData`或者`cancel`方法，然后会调用`didCompleteWithError`代理方法
- 进入后台、代码引起的crash或者被系统关闭，系统会有另外一条进程对下载任务进行管理，没有开启的任务会自动开启，已经开启的会保持原来的状态（继续运行或者暂停），当App重新启动后，创建对应的`Background Sessions`，可以使用`session.getTasksWithCompletionHandler(_:)`方法来获取任务，session的代理方法也会继续被调用（如果需要）
- 最令人意外的是，只要没有手动手动Kill App，就算重启手机，重启完成后原来在运行的下载任务还是会继续下载，实在牛逼

既然已经总结出规律，那么处理起来就简单了：

- 在App启动的时候创建`Background Sessions`
- 使用`cancelByProducingResumeData`方法暂停任务，保证可以恢复任务
  - 其实也可以使用`suspend`方法，但在iOS 10.0 - iOS 10.1 中如果暂停后不马上恢复任务，会无法恢复任务，这又是一个Bug，所以不建议
- 手动Kill App会调用了`cancelByProducingResumeData`或者`cancel`，最后会调用`didCompleteWithError`代理方法，可以在这里做集中处理，把`resumeData`保存起来
- 代码引起的crash或者被系统关闭，不影响原来任务的状态，当App重新启动后，创建对应的`Background Sessions`后，使用`session.getTasksWithCompletionHandler(_:)`来获取任务

#### 下载完成

- 在前台：
- 在后台：

#### 下载错误



#### 重定向



#### 注意事项

xcode的锅，重装会改变app沙盒路径



