//
//  TRManager.swift
//  Tiercel
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018年 Daniels. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit

public class TRManager {

    // 请求超时时间
    public var timeoutIntervalForRequest = 30.0 {
        didSet {
            session.invalidateAndCancel()
            session = setupSession()
        }
    }

    // 最大并发数
    public var maxConcurrentTasksLimit = Int.max

    public static var logLevel: TRLogLevel = .none

    public static var isControlNetworkActivityIndicator = true

    private let queue: DispatchQueue = DispatchQueue(label: "com.Daniels.Tiercel.queue")

    public var cache: TRCache

    private var session: URLSession

    public var isStartDownloadImmediately = true

    private var internalIsRemoveCompletely = false
    private var isRemoveCompletely: Bool {
        get {
            return queue.sync {
                internalIsRemoveCompletely
            }
        }
        set {
            return queue.sync {
                internalIsRemoveCompletely = newValue
            }
        }
    }

    
    private var shouldRun: Bool {
        return runningTasks.count < maxConcurrentTasksLimit
    }


    private var internalIsCompleted: Bool = false
    private var isCompleted: Bool {
        get {
            return queue.sync {
                internalIsCompleted
            }
        }
        set {
            return queue.sync {
                internalIsCompleted = newValue
            }
        }
    }

    private var internalIsSuspend: Bool = true
    private var isSuspend: Bool {
        get {
            return queue.sync {
                internalIsSuspend
            }
        }
        set {
            return queue.sync {
                internalIsSuspend = newValue
            }
        }
    }


    private var internalStatus: TRStatus = .waiting
    public internal(set) var status: TRStatus {
        get {
            return queue.sync {
                internalStatus
            }
        }
        set {
            return queue.sync {
                internalStatus = newValue
            }
        }
    }


    private var internalTasks: [TRTask] = []
    public internal(set) var tasks: [TRTask] {
        get {
            return queue.sync {
                internalTasks
            }
        }
        set {
            return queue.sync {
                internalTasks = newValue
            }
        }
    }


    public var runningTasks: [TRTask] {
        return tasks.filter { $0.status == .running }
    }

    public var completedTasks: [TRTask] {
        return tasks.filter { $0.status == .completed }
    }


    private let internalProgress = Progress()
    public var progress: Progress {
        internalProgress.completedUnitCount = tasks.reduce(0, { $0 + $1.progress.completedUnitCount })
        internalProgress.totalUnitCount = tasks.reduce(0, { $0 + $1.progress.totalUnitCount })
        return internalProgress
    }
    
    private var internalSpeed: Int64 = 0
    public private(set) var speed: Int64 {
        get {
            return queue.sync {
                internalSpeed
            }
        }
        set {
            return queue.sync {
                internalSpeed = newValue
            }
        }
    }


    private var internalTimeRemaining: Int64 = 0
    public private(set) var timeRemaining: Int64 {
        get {
            return queue.sync {
                internalTimeRemaining
            }
        }
        set {
            return queue.sync {
                internalTimeRemaining = newValue
            }
        }
    }
    
    internal var successHandler: TRManagerHandler?
    
    internal var failureHandler: TRManagerHandler?
    
    internal var progressHandler: TRManagerHandler?
    

    
    
    // MARK: - life cycle


    ///  初始化方法
    ///
    /// - Parameters:
    ///   - name: 设置TRManager对象的名字，区分不同的下载模块，每个模块中下载相关的文件会保存到对应的沙盒目录
    ///   - MaximumRunning: 下载的最大并发数
    ///   - isStoreInfo: 是否把下载任务的相关信息持久化到沙盒，如果是，则初始化完成后自动恢复上次的任务
    public init(_ name: String? = nil, MaximumRunning: Int? = nil, isStoreInfo: Bool = false) {
        if name != nil {
            cache = TRCache(name!)
        } else {
            cache = TRCache.default
        }
        cache.isStoreInfo = isStoreInfo

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutIntervalForRequest
        configuration.httpMaximumConnectionsPerHost = 10000
        let sessionDelegate = TRSessionDelegate()
        session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)

        sessionDelegate.manager = self

        if let max = MaximumRunning {
            self.maxConcurrentTasksLimit = max
        }
        if isStoreInfo {
            tasks = cache.retrieveTasks()
            tasks.forEach({ $0.manager = self })
            TiercelLog("retrieveTasks tasks.count = \(tasks.count)")

            //  处理mananger状态
            let isEnd = self.tasks.filter { $0.status != .completed && $0.status != .failed }.isEmpty
            if isEnd {
                let isSuccess = tasks.filter { $0.status == .failed }.isEmpty
                if isSuccess {
                    isCompleted = true
                    status = .completed
                } else {
                    status = .failed
                }
            } else {
                status = .suspend
            }
        }
    }

    private func setupSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutIntervalForRequest
        configuration.httpMaximumConnectionsPerHost = 10000
        let sessionDelegate = TRSessionDelegate()
        sessionDelegate.manager = self
        return URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
    }

    /// 销毁manager
    public func invalidate() {
        totalSuspend()
        session.invalidateAndCancel()
    }
}




// MARK: - download
extension TRManager {


    /// 开启一个下载任务
    ///
    ///
    /// - Parameters:
    ///   - URLString: 需要下载的URLString
    ///   - fileName: 下载文件的文件名，如果传nil，则使用URLString的最后一部分作为文件名
    ///   - params: 参数
    ///   - progressHandler: 当前task的progressHandler
    ///   - successHandler: 当前task的successHandler
    ///   - failureHandler: 当前task的failureHandler
    /// - Returns: 如果URLString有效，则返回对应的task；如果URLString无效，则返回nil
    @discardableResult
    public func download(_ URLString: String, fileName: String? = nil, progressHandler: TRTaskHandler? = nil, successHandler: TRTaskHandler? = nil, failureHandler: TRTaskHandler? = nil) -> TRDownloadTask? {
        status = .waiting

        guard let url = URL(string: URLString) else {
            TiercelLog("[manager] 下载无效的URLString：\(URLString)")
            return nil
        }

        isCompleted = false

        var task = fetchTask(URLString) as? TRDownloadTask
        if task != nil {
            task!.progressHandler = progressHandler
            task!.successHandler = successHandler
            task!.failureHandler = failureHandler
            if let fileName = fileName {
                task!.fileName = fileName
            }
        } else {
            task = TRDownloadTask(url, fileName: fileName, cache: cache, progressHandler: progressHandler, successHandler: successHandler, failureHandler: failureHandler)
            tasks.append(task!)
        }
        if isStartDownloadImmediately {
            start(URLString)
        }

        return task

    }


    /// 批量开启多个下载任务
    /// 所有任务都会并发下载？？
    ///
    /// - Parameters:
    ///   - URLStrings: 需要下载的URLString数组
    ///   - fileNames: 下载文件的文件名，如果传nil，则使用URLString的最后一部分作为文件名
    ///   - params: 参数
    ///   - progressHandler: 每个task的progressHandler
    ///   - successHandler: 每个task的successHandler
    ///   - failureHandler: 每个task的failureHandler
    /// - Returns: 返回URLString数组中有效URString对应的task数组
    @discardableResult
    public func multiDownload(_ URLStrings: [String], fileNames: [String]? = nil, progressHandler: TRTaskHandler? = nil, successHandler: TRTaskHandler? = nil, failureHandler: TRTaskHandler? = nil) -> [TRDownloadTask] {
        status = .waiting

        // 去掉重复, 无效的url
        var uniqueUrls = [URL]()
        URLStrings.forEach { (URLString) in
            if let uniqueUrl = URL(string: URLString) {
                if !uniqueUrls.contains(uniqueUrl) {
                    uniqueUrls.append(uniqueUrl)
                }
            } else {
                TiercelLog("[manager] 下载无效的URLString：\(URLString)")
            }
        }
        
        if uniqueUrls.isEmpty {
            return [TRDownloadTask]()
        }

        isCompleted = false

        var temp = [TRDownloadTask]()
        for url in uniqueUrls {

            var task = fetchTask(url.absoluteString) as? TRDownloadTask
            if task != nil {
                task!.progressHandler = progressHandler
                task!.successHandler = successHandler
                task!.failureHandler = failureHandler
                if let index = URLStrings.index(of: url.absoluteString),
                    let fileName = fileNames?.safeObjectAtIndex(index)  {
                    task!.fileName = fileName
                }
            } else {
                var fileName: String?
                if let fileNames = fileNames, let index = URLStrings.index(of: url.absoluteString) {
                    fileName = fileNames.safeObjectAtIndex(index)
                }

                task = TRDownloadTask(url, fileName: fileName, cache: cache, progressHandler: progressHandler, successHandler: successHandler, failureHandler: failureHandler)
                tasks.append(task!)
            }
            temp.append(task!)
        }

        if isStartDownloadImmediately {
            totalStart()
        }        
        return temp
    }
    

}




// MARK: - single task control
extension TRManager {
    
    public func fetchTask(_ URLString: String) -> TRTask? {
        return tasks.first { $0.URLString == URLString }
    }


    /// 开启任务
    /// 会检查存放下载完成的文件中是否存在跟fileName一样的文件
    /// 如果存在则不会开启下载，直接调用task的successHandler
    public func start(_ URLString: String) {
        guard let task = fetchTask(URLString) as? TRDownloadTask else { return }
        task.manager = self
        task.session = session

        if cache.fileExists(fileName: task.fileName) {
            TiercelLog("[manager] file is exists URLString: \(task.URLString)")
            if let fileInfo = try? FileManager().attributesOfItem(atPath: cache.filePtah(fileName: task.fileName)!), let length = fileInfo[.size] as? Int64 {
                task.progress.totalUnitCount = length
            }
            task.completed()
            self.completed()
            return
        }

        switch task.status {
        case .waiting, .suspend, .failed:

            if shouldRun {
                isSuspend = false

                task.start()
                if status != .running {
                    progress.setUserInfoObject(Date().timeIntervalSince1970, forKey: .estimatedTimeRemainingKey)
                }
                status = .running
            } else {
                task.status = .waiting
                DispatchQueue.main.tr.safeAsync {
                    task.progressHandler?(task)
                }
            }
        case .completed:
            TiercelLog("[manager] task has completed URLString: \(URLString)")
            task.completed()
            self.completed()
        case .running:
            TiercelLog("[manager] task is running URLString: \(URLString)")
        default: break
        }
    }
    


    /// 暂停任务，会触发sessionDelegate的完成回调
    public func suspend(_ URLString: String) {
        guard let task = fetchTask(URLString) else { return }
        task.suspend()
    }

    /// 取消任务
    /// 不会对已经完成的任务造成影响
    /// 其他状态的任务都可以被取消，被取消的任务会被移除
    /// 会保留还没有下载完成的缓存文件
    /// 取消正在运行的任务，会触发sessionDelegate的完成回调，是异步的
    /// 不会触发task的successHandler或者failureHandler
    public func cancel(_ URLString: String) {
        guard let task = fetchTask(URLString) else { return }
        task.cancel()
    }


    /// 移除任务
    /// 所有状态的任务都可以被移除
    /// 会删除还没有下载完成的缓存文件
    /// 可以选择是否删除下载完成的文件
    /// 不会触发task的successHandler或者failureHandler
    ///
    /// - Parameters:
    ///   - URLString: URLString
    ///   - completely: 是否删除下载完成的文件
    public func remove(_ URLString: String, completely: Bool = false) {
        guard let task = fetchTask(URLString) as? TRDownloadTask else { return }
        isRemoveCompletely = completely
        task.remove()
    }

}

// MARK: - total tasks control
extension TRManager {

    public func totalStart() {
        tasks.forEach { (task) in
            start(task.URLString)
        }
    }


    public func totalSuspend() {
        guard status == .running || status == .waiting else { return }
        status = .preSuspend
        tasks.forEach { (task) in
            suspend(task.URLString)
        }

    }

    public func totalCancel() {
        guard status != .completed && status != .cancel else { return }
        status = .preCancel
        tasks.forEach { (task) in
            cancel(task.URLString)
        }
    }

    public func totalRemove(completely: Bool = false) {
        guard status != .remove else { return }
        isCompleted = false
        status = .preRemove
        tasks.forEach { (task) in
            remove(task.URLString, completely: completely)
        }
    }
}

// MARK: - status handle
extension TRManager {


    internal func taskDidCancelOrRemove(_ URLString: String) {
        guard let task = fetchTask(URLString) as? TRDownloadTask else { return }
        cache.removeTaskInfo(task)

        // 把预操作的状态改成完成操作的状态
        if task.status == .preCancel {
            task.status = .cancel
        }

        if task.status == .preRemove {
            task.status = .remove
        }

        if task.status == .remove {
            cache.remove(task, completely: isRemoveCompletely)
        }
        guard let tasksIndex = tasks.index(where: { $0.URLString == task.URLString }) else { return  }
        tasks.remove(at: tasksIndex)


        // 处理使用单个任务操作移除最后一个task时，manager状态
        if tasks.isEmpty {
            if task.status == .cancel {
                status = .preCancel
            }
            if task.status == .remove {
                status = .preRemove
            }
        }
    }

    internal func completed() {

        // 处理移除状态
        if status == .preRemove {
            if tasks.isEmpty {
                status = .remove
                TiercelLog("[manager] all tasks completed and manager failed because its status is \(status)")
                DispatchQueue.main.tr.safeAsync {
                    self.failureHandler?(self)
                }
                return
            }
            return
        }

        // 处理取消状态
        if status == .preCancel {
            let isCancel = tasks.filter { $0.status != .completed }.isEmpty
            if isCancel {
                status = .cancel
                TiercelLog("[manager] all tasks completed and manager failed because its status is \(status)")
                DispatchQueue.main.tr.safeAsync {
                    self.failureHandler?(self)
                }
                return
            }
            return
        }


        // 处理所有任务结束后的状态
        let isEnd = tasks.filter { $0.status != .completed && $0.status != .failed }.isEmpty
        if isEnd {
            if isCompleted {
                return
            }
            isCompleted = true
            timeRemaining = 0
            DispatchQueue.main.tr.safeAsync {
                self.progressHandler?(self)
            }

            // 成功或者失败
            let isSuccess = tasks.filter { $0.status == .failed }.isEmpty
            if isSuccess {
                TiercelLog("[manager] all tasks completed and manager succeeded")
                status = .completed
                DispatchQueue.main.tr.safeAsync {
                    self.successHandler?(self)
                }
            } else {
                TiercelLog("[manager] all tasks completed and manager failed")
                status = .failed
                DispatchQueue.main.tr.safeAsync {
                    self.failureHandler?(self)
                }
            }
            return
        }

        // 处理暂停的状态
        let isSuspend = tasks.reduce(into: true) { (isSuspend, task) in
            if isSuspend {
                if task.status == .suspend || task.status == .completed || task.status == .failed {
                    isSuspend = true
                } else {
                    isSuspend = false
                }
            }
        }

        if isSuspend {
            if self.isSuspend {
                return
            }
            self.isSuspend = true
            TiercelLog("[manager] manager did suspend")
            status = .suspend
            DispatchQueue.main.tr.safeAsync {
                self.successHandler?(self)
            }
            return
        }

        if status == .preSuspend {
            return
        }

        
        // 运行下一个等待中的任务
        let waitingTasks = tasks.filter { $0.status == .waiting }
        if waitingTasks.isEmpty {
            return
        }

        TiercelLog("[manager] start to download next task")
        waitingTasks.forEach({ (task) in
            self.start(task.URLString)
        })
    }
}


// MARK: - info
extension TRManager {
    internal func parseSpeed() {

        // 当前已经完成的大小
        let dataCount = progress.completedUnitCount
        var lastData: Int64 = 0
        if let temp = progress.userInfo[.fileCompletedCountKey] as? Int64 {
            lastData = temp
        }

        let time = Date().timeIntervalSince1970
        var lastTime: Double = 0
        if let temp = progress.userInfo[.estimatedTimeRemainingKey] as? Double {
            lastTime = temp
        }

        let cost = time - lastTime

        // cost作为速度刷新的频率，也作为计算实时速度的时间段
        if cost <= 0.8 {
            if speed == 0 {
                if dataCount > lastData {
                    speed = Int64(Double(dataCount - lastData) / cost)
                    parseTime()
                }
                tasks.forEach({ (task) in
                    if let task = task as? TRDownloadTask {
                        task.parseSpeed(cost)
                    }
                })
            }
            return
        }

        if dataCount > lastData {
            speed = Int64(Double(dataCount - lastData) / cost)
            parseTime()
        }
        tasks.forEach({ (task) in
            if let task = task as? TRDownloadTask {
                task.parseSpeed(cost)
            }
        })

        // 把当前已经完成的大小保存在fileCompletedCountKey，作为下一次的lastData
        progress.setUserInfoObject(dataCount, forKey: .fileCompletedCountKey)

        // 把当前的时间保存在estimatedTimeRemainingKey，作为下一次的lastTime
        progress.setUserInfoObject(time, forKey: .estimatedTimeRemainingKey)

    }

    internal func parseTime() {
        if speed == 0 {
            self.timeRemaining = 0
        } else {
            let timeRemaining = (Double(progress.totalUnitCount) - Double(progress.completedUnitCount)) / Double(speed)
            self.timeRemaining = Int64(timeRemaining)
            if timeRemaining < 1 && timeRemaining > 0.8 {
                self.timeRemaining += 1
            }
        }
    }
}



// MARK: - closure
extension TRManager {
    @discardableResult
    public func progress(_ handler: @escaping TRManagerHandler) -> Self {
        progressHandler = handler
        return self
    }
    
    @discardableResult
    public func success(_ handler: @escaping TRManagerHandler) -> Self {
        successHandler = handler
        return self
    }
    
    @discardableResult
    public func failure(_ handler: @escaping TRManagerHandler) -> Self {
        failureHandler = handler
        return self
    }
}


