//
//  SessionManager.swift
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

public class SessionManager {
    
    public static var logLevel: LogLevel = .detailed

    public static var isControlNetworkActivityIndicator = true

    public let operationQueue: DispatchQueue

    private let dataQueue: DispatchQueue = DispatchQueue(label: "com.Tiercel.SessionManager.dataQueue")

    private let configurationQueue: DispatchQueue = DispatchQueue(label: "com.Tiercel.SessionManager.configurationQueue")

    private let multiDownloadQueue: DispatchQueue = DispatchQueue(label: "com.Tiercel.SessionManager.multiDownloadQueue")

    private var _session: URLSession?
    private var session: URLSession? {
        get {
            return dataQueue.sync {
                _session
            }
        }
        set {
            dataQueue.sync {
                _session = newValue
            }
        }
    }
    
    public let cache: Cache
    
    public let identifier: String
    
    public var completionHandler: (() -> Void)?

    private var _shouldCreatSession: Bool = false
    private var shouldCreatSession: Bool {
        get {
            return dataQueue.sync {
                _shouldCreatSession
            }
        }
        set {
            dataQueue.sync {
                _shouldCreatSession = newValue
            }
        }
    }
    
    private var _configuration: SessionConfiguration {
        didSet {
            guard !shouldCreatSession else { return }
            shouldCreatSession = true
            if status == .running {
                runningTasks = tasks.filter { $0.status == .running }
                waitingTasks = tasks.filter { $0.status == .waiting }
                totalSuspend()
            } else {
                session?.invalidateAndCancel()
                session = nil
            }
        }
    }
    
    public var configuration: SessionConfiguration {
        get {
            return configurationQueue.sync {
                _configuration
            }
        }
        set {
            operationQueue.sync {
                configurationQueue.sync {
                    _configuration = newValue
                }
            }
        }
    }
    
    internal var shouldRun: Bool {
        return tasks.filter { $0.status == .running }.count < configuration.maxConcurrentTasksLimit
    }
    
    
    private var _status: Status = .waiting
    public private(set) var status: Status {
        get {
            return dataQueue.sync {
                _status
            }
        }
        set {
            dataQueue.sync {
                _status = newValue
            }
        }
    }
    
    
    private var _tasks: [Task] = []
    public private(set) var tasks: [Task] {
        get {
            return dataQueue.sync {
                _tasks
            }
        }
        set {
            dataQueue.sync {
                _tasks = newValue
            }
        }
    }
    
    private var _runningTasks = [Task]()
    private var runningTasks: [Task] {
        get {
            return dataQueue.sync {
                _runningTasks
            }
        }
        set {
            dataQueue.sync {
                _runningTasks = newValue
            }
        }
    }
    
    private var _waitingTasks = [Task]()
    private var waitingTasks: [Task] {
        get {
            return dataQueue.sync {
                _waitingTasks
            }
        }
        set {
            dataQueue.sync {
                _waitingTasks = newValue
            }
        }
    }
    
    public var completedTasks: [Task] {
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
            return dataQueue.sync {
                _speed
            }
        }
        set {
            dataQueue.sync {
                _speed = newValue
            }
        }
    }
    
    
    private var _timeRemaining: Int64 = 0
    public private(set) var timeRemaining: Int64 {
        get {
            return dataQueue.sync {
                _timeRemaining
            }
        }
        set {
            dataQueue.sync {
                _timeRemaining = newValue
            }
        }
    }
        
    private var progressExecuter: Executer<SessionManager>?
    
    private var successExecuter: Executer<SessionManager>?
    
    private var failureExecuter: Executer<SessionManager>?
    
    private var controlExecuter: Executer<SessionManager>?

    
    
    public init(_ identifier: String,
                configuration: SessionConfiguration,
                operationQueue: DispatchQueue = DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue")) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.Daniels.Tiercel"
        self.identifier = "\(bundleIdentifier).\(identifier)"
        self._configuration = configuration
        self.operationQueue = operationQueue
        cache = Cache(identifier)
        tasks = cache.retrieveAllTasks() ?? [Task]()
        tasks.forEach {
            $0.manager = self
            $0.operationQueue = operationQueue
        }
        TiercelLog("[manager] retrieveTasks, tasks.count: \(tasks.count)", identifier: self.identifier)
        shouldCreatSession = true
        operationQueue.sync {
            createSession()
            matchStatus()
        }
    }


    private func createSession(_ completion: (() -> ())? = nil) {
        guard shouldCreatSession else { return }
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeoutIntervalForRequest
        sessionConfiguration.httpMaximumConnectionsPerHost = 100000
        sessionConfiguration.allowsCellularAccess = configuration.allowsCellularAccess
        let sessionDelegate = SessionDelegate()
        sessionDelegate.manager = self
        let delegateQueue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: operationQueue, name: "com.Tiercel.SessionManager.delegateQueue")
        session = URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: delegateQueue)
        tasks.forEach { $0.session = session }
        shouldCreatSession = false
        completion?()
    }
    
    private func matchStatus() {
        if self.tasks.isEmpty {
            return
        }
        session?.getTasksWithCompletionHandler { [weak self] (dataTasks, uploadTasks, downloadTasks) in
            guard let self = self else { return }
            downloadTasks.forEach { downloadTask in
                if downloadTask.state == .running,
                    let currentURLString = downloadTask.currentRequest?.url?.absoluteString,
                    let task = self.fetchTask(withCurrentURLString: currentURLString)?.asDownloadTask() {
                    task.status = .running
                    task.task = downloadTask
                    TiercelLog("[downloadTask] runing", identifier: self.identifier, URLString: task.URLString)
                }
            }

            //  处理mananger状态
            let isRunning = self.tasks.filter { $0.status == .running }.count > 0
            if isRunning {
                TiercelLog("[manager] running", identifier: self.identifier)
                self.status = .running
                return
            }

            let isCompleted = self.tasks.filter { $0.status != .succeeded && $0.status != .failed }.isEmpty
            if isCompleted {
                let isSucceeded = self.tasks.filter { $0.status == .failed }.isEmpty
                self.status = isSucceeded ? .succeeded : .failed
            } else {
                self.status = .suspended
            }
        }
    }
}


// MARK: - download
extension SessionManager {
    
    
    /// 开启一个下载任务
    ///
    /// - Parameters:
    ///   - URLString: 需要下载的URLString
    ///   - headers: headers
    ///   - fileName: 下载文件的文件名，如果传nil，则默认为url的md5加上文件扩展名
    /// - Returns: 如果URLString有效，则返回对应的task；如果URLString无效，则返回nil
    @discardableResult
    public func download(_ URLString: String,
                         headers: [String: String]? = nil,
                         fileName: String? = nil) -> DownloadTask? {
        
        guard let url = URL(string: URLString) else {
            TiercelLog("[manager] URLString error：\(URLString)", identifier: identifier)
            return nil
        }
        
        var task: DownloadTask?
        operationQueue.sync {
            task = fetchTask(URLString)?.asDownloadTask()
            if task != nil {
                task?.headers = headers
                if let fileName = fileName, !fileName.isEmpty {
                    task?.fileName = fileName
                }
            } else {
                task = DownloadTask(url,
                                      headers: headers,
                                      fileName: fileName,
                                      cache: cache,
                                      operationQueue: operationQueue)
                task?.manager = self
                task?.session = session
                tasks.append(task!)
            }
            cache.storeTasks(tasks)
        }
        
        start(task!)
        
        return task
    }
    

    /// 批量开启多个下载任务, 所有任务都会并发下载
    ///
    /// - Parameters:
    ///   - URLStrings: 需要下载的URLString数组
    ///   - headers: headers
    ///   - fileNames: 下载文件的文件名，如果传nil，则默认为url的md5加上文件扩展名
    /// - Returns: 返回URLString数组中有效URString对应的task数组
    @discardableResult
    public func multiDownload(_ URLStrings: [String],
                              headers: [[String: String]]? = nil,
                              fileNames: [String]? = nil) -> [DownloadTask] {
        if let headers = headers,
            headers.count != 0 && headers.count != URLStrings.count {
            TiercelLog("[manager] multiDownload error：headers.count != URLStrings.count", identifier: identifier)
            return [DownloadTask]()
        }
        
        if let fileNames = fileNames,
            fileNames.count != 0 && fileNames.count != URLStrings.count {
            TiercelLog("[manager] multiDownload error：fileNames.count != URLStrings.count", identifier: identifier)
            return [DownloadTask]()
        }

        var uniqueTasks = [DownloadTask]()
        multiDownloadQueue.sync {
            for (index, URLString) in URLStrings.enumerated() {
                if !uniqueTasks.contains { $0.URLString == URLString } {
                    let fileName = fileNames?.safeObject(at: index)
                    let header = headers?.safeObject(at: index)
                    if let task = download(URLString, headers: header, fileName: fileName) {
                        uniqueTasks.append(task)
                    }
                }
            }
        }
        return uniqueTasks
    }
}

// MARK: - single task control
extension SessionManager {
    
    public func fetchTask(_ URLString: String) -> Task? {
        return tasks.first { $0.URLString == URLString }
    }
    
    internal func fetchTask(withCurrentURLString: String) -> Task? {
        return tasks.first { $0.currentURLString == withCurrentURLString }
    }
    
    
    /// 开启任务
    /// 会检查存放下载完成的文件中是否存在跟fileName一样的文件
    /// 如果存在则不会开启下载，直接调用task的successHandler
    public func start(_ URLString: String) {
        operationQueue.async {
            guard let task = self.fetchTask(URLString) else { return }
            if !self.shouldCreatSession {
                task.start()
            } else {
                task.status = .suspended
                if !self.waitingTasks.contains(task) {
                    self.waitingTasks.append(task)
                }
            }
        }
    }
    
    public func start(_ task: Task) {
        operationQueue.async {
            if !self.shouldCreatSession {
                task.start()
            } else {
                task.status = .suspended
                if !self.waitingTasks.contains(task) {
                    self.waitingTasks.append(task)
                }
            }
        }
    }

    
    /// 暂停任务，会触发sessionDelegate的完成回调
    public func suspend(_ URLString: String, onMainQueue: Bool = true, _ handler: Handler<Task>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(URLString) else { return }
            task.suspend(onMainQueue: onMainQueue, handler)
        }
    }
    
    /// 取消任务
    /// 不会对已经完成的任务造成影响
    /// 其他状态的任务都可以被取消，被取消的任务会被移除
    /// 会删除还没有下载完成的缓存文件
    /// 会触发sessionDelegate的完成回调
    public func cancel(_ URLString: String, onMainQueue: Bool = true, _ handler: Handler<Task>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(URLString) else { return }
            task.cancel(onMainQueue: onMainQueue, handler)
        }
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
    public func remove(_ URLString: String, completely: Bool = false, onMainQueue: Bool = true, _ handler: Handler<Task>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(URLString) else { return }
            task.remove(completely: completely, onMainQueue: onMainQueue, handler)
        }
    }
    
}

// MARK: - total tasks control
extension SessionManager {
    
    public func totalStart() {
        self.tasks.forEach { task in
            start(task)
        }
    }
    
    
    public func totalSuspend(onMainQueue: Bool = true, _ handler: Handler<SessionManager>? = nil) {
        operationQueue.async {
            guard self.status == .running || self.status == .waiting else { return }
            self.status = .willSuspend
            self.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            self.tasks.forEach { $0.suspend() }
        }

    }
    
    public func totalCancel(onMainQueue: Bool = true, _ handler: Handler<SessionManager>? = nil) {
        operationQueue.async {
            guard self.status != .succeeded && self.status != .canceled else { return }
            self.status = .willCancel
            self.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            self.tasks.forEach { $0.cancel() }
        }
    }
    
    public func totalRemove(completely: Bool = false, onMainQueue: Bool = true, _ handler: Handler<SessionManager>? = nil) {
        operationQueue.async {
            guard self.status != .removed else { return }
            self.status = .willRemove
            self.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            self.tasks.forEach { $0.remove(completely: completely) }
        }
    }
}


// MARK: - status handle
extension SessionManager {
    
    internal func didStart() {
        if status != .running {
            progress.setUserInfoObject(Date().timeIntervalSince1970, forKey: .estimatedTimeRemainingKey)
            status = .running
            TiercelLog("[manager] running", identifier: identifier)
            progressExecuter?.execute(self)
        }
    }
    
    internal func updateProgress() {
        progressExecuter?.execute(self)
    }
    
    internal func didCancelOrRemove(_ URLString: String) {
        guard let task = fetchTask(URLString) else { return }
        guard let tasksIndex = tasks.firstIndex(where: { $0.URLString == task.URLString }) else { return }
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
        TiercelLog("[manager] removed", identifier: identifier)
        controlExecuter?.execute(self)
        failureExecuter?.execute(self)
        return true
    }
    
    private func shouldCancel() -> Bool {
        guard status == .willCancel else { return false }
        
        let isCancel = tasks.filter { $0.status != .succeeded }.isEmpty
        guard isCancel else { return true }
        status = .canceled
        TiercelLog("[manager] canceled", identifier: identifier)
        controlExecuter?.execute(self)
        failureExecuter?.execute(self)
        return true
    }
    
    private func shouldComplete() -> Bool {
        
        let isCompleted = tasks.filter { $0.status != .succeeded && $0.status != .failed }.isEmpty
        guard isCompleted else { return false }

        if status == .succeeded || status == .failed {
            return true
        }
        timeRemaining = 0
        
        progressExecuter?.execute(self)
        
        // 成功或者失败
        let isSucceeded = tasks.filter { $0.status == .failed }.isEmpty
        if isSucceeded {
            status = .succeeded
            TiercelLog("[manager] succeeded", identifier: identifier)
            successExecuter?.execute(self)
        } else {
            status = .failed
            TiercelLog("[manager] failed", identifier: identifier)
            failureExecuter?.execute(self)
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
            TiercelLog("[manager] did suspend", identifier: identifier)
            controlExecuter?.execute(self)
            failureExecuter?.execute(self)
            if shouldCreatSession {
                session?.invalidateAndCancel()
                session = nil
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
        TiercelLog("[manager] start to download the next task", identifier: identifier)
        waitingTasks.forEach { $0.start() }
    }
}


// MARK: - info
extension SessionManager {
    internal func updateSpeedAndTimeRemaining() {
        
        // 当前已经完成的大小
        let currentData = progress.completedUnitCount
        let lastData: Int64 = progress.userInfo[.fileCompletedCountKey] as? Int64 ?? 0
        
        let currentTime = Date().timeIntervalSince1970
        let lastTime: Double = progress.userInfo[.estimatedTimeRemainingKey] as? Double ?? 0

        let costTime = currentTime - lastTime
        
        // costTime作为速度刷新的频率，也作为计算实时速度的时间段
        if costTime <= 0.8 && speed != 0 {
            return
        }
        
        if currentData > lastData {
            speed = Int64(Double(currentData - lastData) / costTime)
            updateTimeRemaining()
        }
        tasks.forEach({ (task) in
            if let task = task.asDownloadTask() {
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
extension SessionManager {
    @discardableResult
    public func progress(onMainQueue: Bool = true, _ handler: @escaping Handler<SessionManager>) -> Self {
        progressExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        return self
    }
    
    @discardableResult
    public func success(onMainQueue: Bool = true, _ handler: @escaping Handler<SessionManager>) -> Self {
        successExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        if status == .succeeded {
            successExecuter?.execute(self)
        }
        return self
    }
    
    @discardableResult
    public func failure(onMainQueue: Bool = true, _ handler: @escaping Handler<SessionManager>) -> Self {
        failureExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        if status == .suspended ||
            status == .canceled ||
            status == .removed ||
            status == .failed  {
            failureExecuter?.execute(self)
        }
        return self
    }
}


// MARK: - call back
extension SessionManager {
    internal func didBecomeInvalidation(withError error: Error?) {
        createSession { [weak self] in
            guard let self = self else { return }
            self.runningTasks.forEach { $0.start() }
            self.runningTasks.removeAll()
            self.waitingTasks.forEach { $0.start() }
            self.waitingTasks.removeAll()
        }
    }
    
    internal func didFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.tr.safeAsync {
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
    
}


