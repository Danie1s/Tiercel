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
    
    public static let `default` = TRManager("default")
    
    public static var logLevel: TRLogLevel = .high
    
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
                runningTasks = tasks.filter({ $0.status == .running })
                totalSuspend()
                shouldCreatSession = true
                session.invalidateAndCancel()
            }
        }
    }
    
    
    private var _isRemoveCompletely = false
    private var isRemoveCompletely: Bool {
        get {
            return queue.sync {
                _isRemoveCompletely
            }
        }
        set {
            return queue.sync {
                _isRemoveCompletely = newValue
            }
        }
    }
    
    private var _isCompleted: Bool = false
    private var isCompleted: Bool {
        get {
            return queue.sync {
                _isCompleted
            }
        }
        set {
            return queue.sync {
                _isCompleted = newValue
            }
        }
    }
    
    private var _isSuspended: Bool = true
    private var isSuspended: Bool {
        get {
            return queue.sync {
                _isSuspended
            }
        }
        set {
            return queue.sync {
                _isSuspended = newValue
            }
        }
    }
    
    private var shouldRun: Bool {
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
    
    public var runningTasks = [TRTask]()
    
    public var completedTasks: [TRTask] {
        return tasks.filter { $0.status == .completed }
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
    
    private var successHandler: TRManagerHandler?
    
    private var failureHandler: TRManagerHandler?
    
    private var progressHandler: TRManagerHandler?
    
    
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
            completion?()
            shouldCreatSession = false
            
        }
    }
    
    private func matchStatus() {
        session.getTasksWithCompletionHandler { [weak self] (dataTasks, uploadTasks, downloadTasks) in
            guard let strongSelf = self else { return }
            strongSelf.tasks.forEach({ (task) in
                if let task = task as? TRDownloadTask {
                    downloadTasks.forEach({ (downloadTask) in
                        if task.currentURLString == downloadTask.currentRequest?.url?.absoluteString,
                            downloadTask.state == .running {
                            task.status = .running
                            task.task = downloadTask
                            TiercelLog("[downloadTask] runing, manager.identifier: \(strongSelf.identifier), URLString: \(task.URLString)")

                        }
                    })
                }
            })

            //  处理mananger状态
            let isRunning = strongSelf.tasks.filter { $0.status == .running }.count > 0
            if isRunning {
                TiercelLog("[manager] running, manager.identifier: \(strongSelf.identifier)")
                strongSelf.status = .running
                strongSelf.isSuspended = false
                return
            }

            let isEnd = strongSelf.tasks.filter { $0.status != .completed && $0.status != .failed }.isEmpty
            if isEnd {
                let isSuccess = strongSelf.tasks.filter { $0.status == .failed }.isEmpty
                if isSuccess {
                    strongSelf.isCompleted = true
                    strongSelf.status = .completed
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
    public func download(_ URLString: String, fileName: String? = nil, progressHandler: TRTaskHandler? = nil, successHandler: TRTaskHandler? = nil, failureHandler: TRTaskHandler? = nil) -> TRDownloadTask? {
        status = .waiting
        
        guard let url = URL(string: URLString) else {
            TiercelLog("[manager] URLString错误：\(URLString), manager.identifier: \(identifier)")
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
            cache.storeTasks(tasks)
        }
        start(URLString)
        
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
                TiercelLog("[manager] URLString错误：\(URLString), manager.identifier: \(identifier)")
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
                    let fileName = fileNames?.safeObjectAtIndex(index) {
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
        
        totalStart()

        return temp
    }
}

// MARK: - single task control
extension TRManager {
    
    public func fetchTask(_ URLString: String) -> TRTask? {
        return tasks.first { $0.URLString == URLString }
    }
    
    internal func fetchTask(with currentURLString: String) -> TRTask? {
        return tasks.first { $0.currentURLString == currentURLString }
    }
    
    
    /// 开启任务
    /// 会检查存放下载完成的文件中是否存在跟fileName一样的文件
    /// 如果存在则不会开启下载，直接调用task的successHandler
    public func start(_ URLString: String) {
        guard let task = fetchTask(URLString) as? TRDownloadTask else { return }
        task.manager = self
        task.session = session
        
        if cache.fileExists(fileName: task.fileName) {
            TiercelLog("[manager] 文件已经存在 URLString: \(task.URLString), manager.identifier: \(identifier)")

            if let fileInfo = try? FileManager().attributesOfItem(atPath: cache.filePtah(fileName: task.fileName)!), let length = fileInfo[.size] as? Int64 {
                task.progress.totalUnitCount = length
            }
            task.completed()
            completed()
            return
        }
        
        switch task.status {
        case .waiting, .suspended, .failed:
            if shouldRun {
                isSuspended = false
                
                task.start()
                if status != .running {
                    progress.setUserInfoObject(Date().timeIntervalSince1970, forKey: .estimatedTimeRemainingKey)
                    TiercelLog("[manager] running, manager.identifier: \(identifier)")
                }
                status = .running
            } else {
                task.status = .waiting
                TiercelLog("[manager] task is waiting URLString: \(task.URLString), manager.identifier: \(identifier)")
                DispatchQueue.main.tr.safeAsync {
                    task.progressHandler?(task)
                }
            }
        case .completed:
            task.completed()
            self.completed()
        case .running:
            TiercelLog("[manager] task is running URLString: \(task.URLString), manager.identifier: \(identifier)")
        default: break
        }
        cache.storeTasks(tasks)

    }
    
    /// 暂停任务，会触发sessionDelegate的完成回调
    public func suspend(_ URLString: String) {
        guard let task = fetchTask(URLString) else { return }
        task.suspend()
    }
    
    /// 取消任务
    /// 不会对已经完成的任务造成影响
    /// 其他状态的任务都可以被取消，被取消的任务会被移除
    /// 会删除还没有下载完成的缓存文件
    /// 会触发sessionDelegate的完成回调
    public func cancel(_ URLString: String) {
        guard let task = fetchTask(URLString) else { return }
        task.cancel()
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
        status = .willSuspend
        tasks.forEach { (task) in
            suspend(task.URLString)
        }
        
    }
    
    public func totalCancel() {
        guard status != .completed && status != .canceled else { return }
        status = .willCancel
        tasks.forEach { (task) in
            cancel(task.URLString)
        }
    }
    
    public func totalRemove(completely: Bool = false) {
        guard status != .removed else { return }
        isCompleted = false
        status = .willRemove
        tasks.forEach { (task) in
            remove(task.URLString, completely: completely)
        }
    }
}


// MARK: - status handle
extension TRManager {
    internal func updateProgress() {
        progressHandler?(self)
    }
    
    internal func taskDidCancelOrRemove(_ URLString: String) {
        guard let task = fetchTask(URLString) as? TRDownloadTask else { return }
        
        // 把预操作的状态改成完成操作的状态
        if task.status == .willCancel {
            task.status = .canceled
        }
        
        if task.status == .willRemove {
            task.status = .removed
        }
        cache.remove(task, completely: isRemoveCompletely)
        

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
        if status == .willRemove {
            if tasks.isEmpty {
                status = .removed
                TiercelLog("[manager] removed, manager.identifier: \(identifier)")
                DispatchQueue.main.tr.safeAsync {
                    self.failureHandler?(self)
                }
                return
            }
            return
        }
        
        // 处理取消状态
        if status == .willCancel {
            let isCancel = tasks.filter { $0.status != .completed }.isEmpty
            if isCancel {
                status = .canceled
                TiercelLog("[manager] canceled, manager.identifier: \(identifier)")
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
                status = .completed
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
            return
        }
        
        // 处理暂停的状态
        let isSuspended = tasks.reduce(into: true) { (isSuspend, task) in
            if isSuspend {
                if task.status == .suspended || task.status == .completed || task.status == .failed {
                    isSuspend = true
                } else {
                    isSuspend = false
                }
            }
        }
        
        if isSuspended {
            if self.isSuspended {
                return
            }
            self.isSuspended = true
            status = .suspended
            TiercelLog("[manager] did suspend, manager.identifier: \(identifier)")
            DispatchQueue.main.tr.safeAsync {
                self.successHandler?(self)
            }
            return
        }
        
        if status == .willSuspend {
            return
        }
        
        
        // 运行下一个等待中的任务
        let waitingTasks = tasks.filter { $0.status == .waiting }
        if waitingTasks.isEmpty {
            return
        }
        TiercelLog("[manager] start to download the next task, manager.identifier: \(identifier)")
        waitingTasks.forEach({ (task) in
            self.start(task.URLString)
        })
    }
}


// MARK: - info
extension TRManager {
    internal func updateSpeedAndTimeRemaining() {
        
        // 当前已经完成的大小
        let dataCount = progress.completedUnitCount
        let lastData: Int64 = progress.userInfo[.fileCompletedCountKey] as? Int64 ?? 0
        
        let time = Date().timeIntervalSince1970
        let lastTime: Double = progress.userInfo[.estimatedTimeRemainingKey] as? Double ?? 0

        let costTime = time - lastTime
        
        // costTime作为速度刷新的频率，也作为计算实时速度的时间段
        if costTime <= 0.8 {
            if speed == 0 {
                if dataCount > lastData {
                    speed = Int64(Double(dataCount - lastData) / costTime)
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
        
        if dataCount > lastData {
            speed = Int64(Double(dataCount - lastData) / costTime)
            updateTimeRemaining()
        }
        tasks.forEach({ (task) in
            if let task = task as? TRDownloadTask {
                task.updateSpeedAndTimeRemaining(costTime)
            }
        })
        
        // 把当前已经完成的大小保存在fileCompletedCountKey，作为下一次的lastData
        progress.setUserInfoObject(dataCount, forKey: .fileCompletedCountKey)
        
        // 把当前的时间保存在estimatedTimeRemainingKey，作为下一次的lastTime
        progress.setUserInfoObject(time, forKey: .estimatedTimeRemainingKey)
        
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


// MARK: - call back
extension TRManager {
    internal func didBecomeInvalidWithError(error: Error?) {
        createSession { [weak self] in
//            guard let strongSelf = self else { return }
//            strongSelf.runningTasks.forEach({ (task) in
//                task.start()
//            })
//            strongSelf.runningTasks.removeAll()
        }
    }
    
    internal func didFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.tr.safeAsync {
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
    
}


