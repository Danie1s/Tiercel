//
//  TRManager.swift
//  Tiercel
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
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

public class TRManager: TRHandleable {
    
    public static let `default` = TRManager("default")
    
    public static var logLevel: TRLogLevel = .detailed
    
    public static var isControlNetworkActivityIndicator = true

    private let queue: DispatchQueue = DispatchQueue(label: "com.Daniels.Tiercel.queue")
    
    public var session: URLSession!
    
    public let cache: TRCache
    
    public let identifier: String
    
    public var completionHandler: (() -> Void)?

    private var shouldCreatSession: Bool = false
    
    public var configuration = TRConfiguration() {
        didSet {
            if !shouldCreatSession {
                if status == .running {
                    runningTasks = tasks.filter({ $0.status == .running })
                    waitingTasks = tasks.filter({ $0.status == .waiting })
                    shouldCreatSession = true
                    totalSuspend()
                } else {
                    shouldCreatSession = true
                    session.invalidateAndCancel()
                }
            }
        }
    }
    
    internal var shouldRun: Bool {
        return tasks.filter { $0.status == .running }.count < configuration.maxConcurrentTasksLimit
    }
    
    
    private var _status: TRStatus = .waiting
    public private(set) var status: TRStatus {
        get {
            return queue.sync {
                _status
            }
        }
        set {
            return queue.sync {
                _status = newValue
            }
        }
    }
    
    
    private var _tasks: [TRTask] = []
    public private(set) var tasks: [TRTask] {
        get {
            return queue.sync {
                _tasks
            }
        }
        set {
            return queue.sync {
                _tasks = newValue
            }
        }
    }
    
    private var runningTasks = [TRTask]()
    
    private var waitingTasks = [TRTask]()

    
    public var completedTasks: [TRTask] {
        return tasks.filter { $0.status == .succeeded }
    }
    
    private let _progress = Progress()
    public var progress: Progress {
        _progress.completedUnitCount = tasks.reduce(0, { $0 + $1.progress.completedUnitCount })
        _progress.totalUnitCount = tasks.reduce(0, { $0 + $1.progress.totalUnitCount })
        return _progress
    }
    
    private var _speed: Int64 = 0
    public private(set) var speed: Int64 {
        get {
            return queue.sync {
                _speed
            }
        }
        set {
            return queue.sync {
                _speed = newValue
            }
        }
    }
    
    
    private var _timeRemaining: Int64 = 0
    public private(set) var timeRemaining: Int64 {
        get {
            return queue.sync {
                _timeRemaining
            }
        }
        set {
            return queue.sync {
                _timeRemaining = newValue
            }
        }
    }
    
    public typealias CompatibleType = TRManager
    
    public var progressHandler: TRHandler<TRManager>?
    
    public var successHandler: TRHandler<TRManager>?
    
    public var failureHandler: TRHandler<TRManager>?
    
    private var controlHandler: TRHandler<TRManager>?

    
    public init(_ identifier: String) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.Daniels.Tiercel"
        self.identifier = "\(bundleIdentifier).\(identifier)"
        if identifier == "default" {
            cache = TRCache.default
        } else {
            cache = TRCache(identifier)
        }
        shouldCreatSession = true
        tasks = cache.retrieveAllTasks() ?? [TRTask]()
        tasks.forEach({ $0.manager = self })
        createSession()

        TiercelLog("[manager] retrieveTasks, tasks.count: \(tasks.count), manager.identifier: \(self.identifier)")

        matchStatus()
    }


    private func createSession(_ completion: (() -> ())? = nil) {
        if shouldCreatSession {
            let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
            sessionConfiguration.timeoutIntervalForRequest = configuration.timeoutIntervalForRequest
            sessionConfiguration.httpMaximumConnectionsPerHost = 10000
            sessionConfiguration.allowsCellularAccess = configuration.allowsCellularAccess
            let sessionDelegate = TRSessionDelegate()
            sessionDelegate.manager = self
            session = URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: nil)
            tasks.forEach({ $0.session = session })
            shouldCreatSession = false
            completion?()
        }
    }
    
    private func matchStatus() {
        session.getTasksWithCompletionHandler { [weak self] (dataTasks, uploadTasks, downloadTasks) in
            guard let strongSelf = self else { return }
            downloadTasks.forEach({ (downloadTask) in
                if let currentURLString = downloadTask.currentRequest?.url?.absoluteString,
                    let task = strongSelf.fetchTask(currentURLString: currentURLString) as? TRDownloadTask,
                    downloadTask.state == .running {
                    task.status = .running
                    task.task = downloadTask
                    TiercelLog("[downloadTask] runing, manager.identifier: \(strongSelf.identifier), URLString: \(task.URLString)")
                }
            })

            //  处理mananger状态
            if strongSelf.tasks.isEmpty {
                strongSelf.status = .waiting
                return
            }
            
            let isRunning = strongSelf.tasks.filter { $0.status == .running }.count > 0
            if isRunning {
                TiercelLog("[manager] running, manager.identifier: \(strongSelf.identifier)")
                strongSelf.status = .running
                return
            }

            let isCompleted = strongSelf.tasks.filter { $0.status != .succeeded && $0.status != .failed }.isEmpty
            if isCompleted {
                let isSucceeded = strongSelf.tasks.filter { $0.status == .failed }.isEmpty
                if isSucceeded {
                    strongSelf.status = .succeeded
                } else {
                    strongSelf.status = .failed
                }
            } else {
                strongSelf.status = .suspended
            }
        }
    }
}


// MARK: - download
extension TRManager {
    
    
    /// 开启一个下载任务
    ///
    ///
    /// - Parameters:
    ///   - URLString: 需要下载的URLString
    ///   - fileName: 下载文件的文件名，如果传nil，则默认为url的md5加上文件扩展名
    ///   - params: 参数
    ///   - progressHandler: 当前task的progressHandler
    ///   - successHandler: 当前task的successHandler
    ///   - failureHandler: 当前task的failureHandler
    /// - Returns: 如果URLString有效，则返回对应的task；如果URLString无效，则返回nil
    @discardableResult
    public func download(_ URLString: String,
                         headers: [String: String]? = nil,
                         fileName: String? = nil) -> TRDownloadTask? {
        
        guard let url = URL(string: URLString) else {
            TiercelLog("[manager] URLString错误：\(URLString), manager.identifier: \(identifier)")
            return nil
        }
        
        var task = fetchTask(URLString) as? TRDownloadTask
        if task != nil {
            task?.headers = headers
            if let fileName = fileName {
                task?.fileName = fileName
            }
        } else {
            task = TRDownloadTask(url,
                                  headers: headers,
                                  fileName: fileName,
                                  cache: cache)
            task?.manager = self
            task?.session = session
            tasks.append(task!)
        }
        task?.start()
        
        return task
        
    }
    
    /// 批量开启多个下载任务
    /// 所有任务都会并发下载
    ///
    /// - Parameters:
    ///   - URLStrings: 需要下载的URLString数组
    ///   - fileNames: 下载文件的文件名，如果传nil，则默认为url的md5加上文件扩展名
    ///   - params: 参数
    ///   - progressHandler: 每个task的progressHandler
    ///   - successHandler: 每个task的successHandler
    ///   - failureHandler: 每个task的failureHandler
    /// - Returns: 返回URLString数组中有效URString对应的task数组
    @discardableResult
    public func multiDownload(_ URLStrings: [String],
                              headers: [[String: String]]? = nil,
                              fileNames: [String]? = nil) -> [TRDownloadTask] {
        
        // 去掉重复, 无效的url
        var uniqueUrls = [URL]()
        URLStrings.forEach { (URLString) in
            if let uniqueUrl = URL(string: URLString) {
                if !uniqueUrls.contains(uniqueUrl) {
                    uniqueUrls.append(uniqueUrl)
                }
            } else {
                TiercelLog("[manager] URLString错误：\(URLString), manager.identifier: \(identifier)")
            }
        }
        
        if uniqueUrls.isEmpty {
            return [TRDownloadTask]()
        }
        
        
        var temp = [TRDownloadTask]()
        for url in uniqueUrls {
            var task = fetchTask(url.absoluteString) as? TRDownloadTask
            if task != nil {
                if let index = URLStrings.index(of: url.absoluteString) {
                    task?.headers = headers?.safeObjectAtIndex(index)
                    if let fileName = fileNames?.safeObjectAtIndex(index) {
                        task?.fileName = fileName
                    }
                }
            } else {
                var fileName: String?
                var header: [String: String]?
                if let index = URLStrings.index(of: url.absoluteString) {
                    fileName = fileNames?.safeObjectAtIndex(index)
                    header = headers?.safeObjectAtIndex(index)
                }
                task = TRDownloadTask(url,
                                      headers: header,
                                      fileName: fileName,
                                      cache: cache)
                task?.manager = self
                task?.session = session
                tasks.append(task!)
            }
            temp.append(task!)
        }

        temp.forEach { $0.start() }

        return temp
    }
}

// MARK: - single task control
extension TRManager {
    
    public func fetchTask(_ URLString: String) -> TRTask? {
        return tasks.first { $0.URLString == URLString }
    }
    
    internal func fetchTask(currentURLString: String) -> TRTask? {
        return tasks.first { $0.currentURLString == currentURLString }
    }
    
    
    /// 开启任务
    /// 会检查存放下载完成的文件中是否存在跟fileName一样的文件
    /// 如果存在则不会开启下载，直接调用task的successHandler
    public func start(_ URLString: String) {
        guard let task = fetchTask(URLString) as? TRDownloadTask else { return }
        task.start()
    }

    
    /// 暂停任务，会触发sessionDelegate的完成回调
    public func suspend(_ URLString: String, handler: TRHandler<TRTask>? = nil) {
        guard let task = fetchTask(URLString) else { return }
        task.suspend(handler)
    }
    
    /// 取消任务
    /// 不会对已经完成的任务造成影响
    /// 其他状态的任务都可以被取消，被取消的任务会被移除
    /// 会删除还没有下载完成的缓存文件
    /// 会触发sessionDelegate的完成回调
    public func cancel(_ URLString: String, _ handler: TRHandler<TRTask>? = nil) {
        guard let task = fetchTask(URLString) else { return }
        task.cancel(handler)
    }
    
    
    /// 移除任务
    /// 所有状态的任务都可以被移除
    /// 会删除还没有下载完成的缓存文件
    /// 可以选择是否删除下载完成的文件
    /// 会触发sessionDelegate的完成回调
    ///
    /// - Parameters:
    ///   - URLString: URLString
    ///   - completely: 是否删除下载完成的文件
    public func remove(_ URLString: String, completely: Bool = false, _ handler: TRHandler<TRTask>? = nil) {
        guard let task = fetchTask(URLString) else { return }
        task.remove(completely: completely, handler)
    }
    
}

// MARK: - total tasks control
extension TRManager {
    
    public func totalStart() {
        tasks.forEach { $0.start() }
    }
    
    
    public func totalSuspend(_ handler: TRHandler<TRManager>? = nil) {
        guard status == .running || status == .waiting else { return }
        status = .willSuspend
        controlHandler = handler
        tasks.forEach { $0.suspend() }
    }
    
    public func totalCancel(_ handler: TRHandler<TRManager>? = nil) {
        guard status != .succeeded && status != .canceled else { return }
        status = .willCancel
        controlHandler = handler
        tasks.forEach { $0.cancel() }
    }
    
    public func totalRemove(completely: Bool = false, _ handler: TRHandler<TRManager>? = nil) {
        guard status != .removed else { return }
        status = .willRemove
        controlHandler = handler
        tasks.forEach { $0.remove(completely: completely) }
    }
}


// MARK: - status handle
extension TRManager {
    
    internal func didStart() {
        if status != .running {
            progress.setUserInfoObject(Date().timeIntervalSince1970, forKey: .estimatedTimeRemainingKey)
            status = .running
            TiercelLog("[manager] running, manager.identifier: \(identifier)")
            DispatchQueue.main.tr.safeAsync {
                self.progressHandler?(self)
            }
        }
    }
    
    internal func updateProgress() {
        progressHandler?(self)
    }
    
    internal func didCancelOrRemove(_ URLString: String) {
        guard let task = fetchTask(URLString) else { return }

        guard let tasksIndex = tasks.index(where: { $0.URLString == task.URLString }) else { return  }
        tasks.remove(at: tasksIndex)
        
        
        // 处理使用单个任务操作移除最后一个task时，manager状态
        if tasks.isEmpty {
            if task.status == .canceled {
                status = .willCancel
            }
            if task.status == .removed {
                status = .willRemove
            }
        }
    }
    
    internal func completed() {
        cache.storeTasks(tasks)
        
        // 处理移除状态
        if shouldRemove() {
            return
        }
        
        // 处理取消状态
        if shouldCancel() {
            return
        }
        
        // 处理所有任务结束后的状态
        if shouldComplete() {
            return
        }

        // 处理暂停状态
        if shouldSuspend() {
            return
        }

        // 运行下一个等待中的任务
        startNextTask()
    }
    
    
    private func shouldRemove() -> Bool {
        guard status == .willRemove else { return false }
        guard tasks.isEmpty else { return true }

        status = .removed
        TiercelLog("[manager] removed, manager.identifier: \(identifier)")
        DispatchQueue.main.tr.safeAsync {
            self.controlHandler?(self)
            self.failureHandler?(self)
        }
        return true
    }
    
    private func shouldCancel() -> Bool {
        guard status == .willCancel else { return false }
        
        let isCancel = tasks.filter { $0.status != .succeeded }.isEmpty
        guard isCancel else { return true }
        status = .canceled
        TiercelLog("[manager] canceled, manager.identifier: \(identifier)")
        DispatchQueue.main.tr.safeAsync {
            self.controlHandler?(self)
            self.failureHandler?(self)
        }
        return true
    }
    
    private func shouldComplete() -> Bool {
        
        let isCompleted = tasks.filter { $0.status != .succeeded && $0.status != .failed }.isEmpty
        guard isCompleted else { return false }

        if status == .succeeded || status == .failed {
            return true
        }
        timeRemaining = 0
        DispatchQueue.main.tr.safeAsync {
            self.progressHandler?(self)
        }
        
        // 成功或者失败
        let isSucceeded = tasks.filter { $0.status == .failed }.isEmpty
        if isSucceeded {
            status = .succeeded
            TiercelLog("[manager] succeeded, manager.identifier: \(identifier)")
            DispatchQueue.main.tr.safeAsync {
                self.successHandler?(self)
            }
        } else {
            status = .failed
            TiercelLog("[manager] failed, manager.identifier: \(identifier)")
            DispatchQueue.main.tr.safeAsync {
                self.failureHandler?(self)
            }
        }
        return true
    }
    
    private func shouldSuspend() -> Bool {
        let isSuspended = tasks.filter { $0.status != .suspended && $0.status != .succeeded && $0.status != .failed }.isEmpty

        if isSuspended {
            if status == .suspended {
                return true
            }
            status = .suspended
            TiercelLog("[manager] did suspend, manager.identifier: \(identifier)")
            DispatchQueue.main.tr.safeAsync {
                self.controlHandler?(self)
                self.failureHandler?(self)
            }
            if shouldCreatSession {
                session.invalidateAndCancel()
            }
            return true
        }
        
        if status == .willSuspend {
            return true
        }
        
        return false
    }
    
    private func startNextTask() {
        let waitingTasks = tasks.filter { $0.status == .waiting }
        if waitingTasks.isEmpty {
            return
        }
        TiercelLog("[manager] start to download the next task, manager.identifier: \(identifier)")
        waitingTasks.forEach { $0.start() }
    }
}


// MARK: - info
extension TRManager {
    internal func updateSpeedAndTimeRemaining() {
        
        // 当前已经完成的大小
        let currentData = progress.completedUnitCount
        let lastData: Int64 = progress.userInfo[.fileCompletedCountKey] as? Int64 ?? 0
        
        let currentTime = Date().timeIntervalSince1970
        let lastTime: Double = progress.userInfo[.estimatedTimeRemainingKey] as? Double ?? 0

        let costTime = currentTime - lastTime
        
        // costTime作为速度刷新的频率，也作为计算实时速度的时间段
        if costTime <= 0.8 {
            if speed == 0 {
                if currentData > lastData {
                    speed = Int64(Double(currentData - lastData) / costTime)
                    updateTimeRemaining()
                }
                tasks.forEach({ (task) in
                    if let task = task as? TRDownloadTask {
                        task.updateSpeedAndTimeRemaining(costTime)
                    }
                })
            }
            return
        }
        
        if currentData > lastData {
            speed = Int64(Double(currentData - lastData) / costTime)
            updateTimeRemaining()
        }
        tasks.forEach({ (task) in
            if let task = task as? TRDownloadTask {
                task.updateSpeedAndTimeRemaining(costTime)
            }
        })
        
        // 把当前已经完成的大小保存在fileCompletedCountKey，作为下一次的lastData
        progress.setUserInfoObject(currentData, forKey: .fileCompletedCountKey)
        
        // 把当前的时间保存在estimatedTimeRemainingKey，作为下一次的lastTime
        progress.setUserInfoObject(currentTime, forKey: .estimatedTimeRemainingKey)
        
    }
    
    private func updateTimeRemaining() {
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
    public func progress(_ handler: @escaping TRHandler<TRManager>) -> Self {
        progressHandler = handler
        return self
    }
    
    @discardableResult
    public func success(_ handler: @escaping TRHandler<TRManager>) -> Self {
        successHandler = handler
        if status == .succeeded {
            DispatchQueue.main.tr.safeAsync {
                self.successHandler?(self)
            }
        }
        return self
    }
    
    @discardableResult
    public func failure(_ handler: @escaping TRHandler<TRManager>) -> Self {
        failureHandler = handler
        if status == .suspended ||
            status == .canceled ||
            status == .removed ||
            status == .failed  {
            DispatchQueue.main.tr.safeAsync {
                self.failureHandler?(self)
            }
        }
        return self
    }
}


// MARK: - call back
extension TRManager {
    internal func didBecomeInvalidWithError(_ error: Error?) {
        createSession { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.runningTasks.forEach({ $0.start() })
            strongSelf.runningTasks.removeAll()
            strongSelf.waitingTasks.forEach({ $0.start() })
            strongSelf.waitingTasks.removeAll()
        }
    }
    
    internal func didFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.tr.safeAsync {
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
    
}


