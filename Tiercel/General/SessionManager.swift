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

    private var timer: DispatchSourceTimer?
    
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
    
    
    private var _tasks: [DownloadTask] = []
    public private(set) var tasks: [DownloadTask] {
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
    
    private var _runningTasks = [DownloadTask]()
    private var runningTasks: [DownloadTask] {
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
    
    private var _waitingTasks = [DownloadTask]()
    private var waitingTasks: [DownloadTask] {
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
    
    public var completedTasks: [DownloadTask] {
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
        cache.decoder.userInfo[.operationQueue] = operationQueue
        tasks = cache.retrieveAllTasks()
        tasks.forEach {
            $0.manager = self
            $0.operationQueue = operationQueue
        }
        TiercelLog("[manager] retrieveTasks, tasks.count: \(tasks.count)", identifier: self.identifier)
        shouldCreatSession = true
        operationQueue.sync {
            createSession()
            updateStatus()
        }
    }

    public func invalidate() {
        session?.invalidateAndCancel()
        session = nil
        invalidateTimer()
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
    
    private func updateStatus() {
        if self.tasks.isEmpty {
            return
        }
        session?.getTasksWithCompletionHandler { [weak self] (dataTasks, uploadTasks, downloadTasks) in
            guard let self = self else { return }
            downloadTasks.forEach { downloadTask in
                if downloadTask.state == .running,
                    let currentURL = downloadTask.currentRequest?.url,
                    let task = self.fetchTask(currentURL: currentURL) {
                    task.status = .running
                    task.task = downloadTask
                    TiercelLog("[downloadTask] runing", identifier: self.identifier, url: task.url)
                }
            }

            //  处理mananger状态
            let isRunning = self.tasks.filter { $0.status == .running }.count > 0
            if isRunning {
                self.didStart()
                return
            }

            if !self.shouldComplete() {
                self.shouldSuspend()
            }
        }
    }


}


// MARK: - download
extension SessionManager {
    
    
    /// 开启一个下载任务
    ///
    /// - Parameters:
    ///   - url: URLConvertible
    ///   - headers: headers
    ///   - fileName: 下载文件的文件名，如果传nil，则默认为url的md5加上文件扩展名
    /// - Returns: 如果url有效，则返回对应的task；如果url无效，则返回nil
    @discardableResult
    public func download(_ url: URLConvertible,
                         headers: [String: String]? = nil,
                         fileName: String? = nil) -> DownloadTask? {
        do {
            let validURL = try url.asURL()
            var task: DownloadTask?
            operationQueue.sync {
                task = fetchTask(validURL)
                if let task = task {
                    task.headers = headers
                    if let fileName = fileName {
                        task.updateFileName(fileName)
                    }
                } else {
                    task = DownloadTask(validURL,
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
        } catch {
            TiercelLog("[manager] url error：\(url)", identifier: identifier)
            return nil
        }

    }
    

    /// 批量开启多个下载任务, 所有任务都会并发下载
    ///
    /// - Parameters:
    ///   - urls: [URLConvertible]
    ///   - headers: headers
    ///   - fileNames: 下载文件的文件名，如果传nil，则默认为url的md5加上文件扩展名
    /// - Returns: 返回url数组中有效url对应的task数组
    @discardableResult
    public func multiDownload(_ urls: [URLConvertible],
                              headers: [[String: String]]? = nil,
                              fileNames: [String]? = nil) -> [DownloadTask] {
        if let headers = headers,
            headers.count != 0 && headers.count != urls.count {
            TiercelLog("[manager] multiDownload error：headers.count != urls.count", identifier: identifier)
            return [DownloadTask]()
        }
        
        if let fileNames = fileNames,
            fileNames.count != 0 && fileNames.count != urls.count {
            TiercelLog("[manager] multiDownload error：fileNames.count != urls.count", identifier: identifier)
            return [DownloadTask]()
        }

        var uniqueTasks = [DownloadTask]()

        multiDownloadQueue.sync {
            for (index, url) in urls.enumerated() {
                let fileName = fileNames?.safeObject(at: index)
                let header = headers?.safeObject(at: index)
                if let task = download(url, headers: header, fileName: fileName),
                    !uniqueTasks.contains { $0.url == task.url }{
                    uniqueTasks.append(task)
                }
            }
        }
        return uniqueTasks
    }
}

// MARK: - single task control
extension SessionManager {
    
    public func fetchTask(_ url: URLConvertible) -> DownloadTask? {
        do {
            let validURL = try url.asURL()
            return tasks.first { $0.url == validURL }
        } catch {
            return nil
        }
    }
    
    internal func fetchTask(currentURL: URLConvertible) -> DownloadTask? {
        do {
            let validURL = try currentURL.asURL()
            return tasks.first { $0.currentURL == validURL }
        } catch {
            return nil
        }
    }
    
    
    /// 开启任务
    /// 会检查存放下载完成的文件中是否存在跟fileName一样的文件
    /// 如果存在则不会开启下载，直接调用task的successHandler
    public func start(_ url: URLConvertible) {
        operationQueue.async {
            guard let task = self.fetchTask(url) else { return }
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
    
    public func start(_ task: DownloadTask) {
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
    public func suspend(_ url: URLConvertible, onMainQueue: Bool = true, _ handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(url) else { return }
            task.suspend(onMainQueue: onMainQueue, handler)
        }
    }
    
    /// 取消任务
    /// 不会对已经完成的任务造成影响
    /// 其他状态的任务都可以被取消，被取消的任务会被移除
    /// 会删除还没有下载完成的缓存文件
    /// 会触发sessionDelegate的完成回调
    public func cancel(_ url: URLConvertible, onMainQueue: Bool = true, _ handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(url) else { return }
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
    ///   - url: URLConvertible
    ///   - completely: 是否删除下载完成的文件
    public func remove(_ url: URLConvertible, completely: Bool = false, onMainQueue: Bool = true, _ handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(url) else { return }
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
            createTimer()
            status = .running
            TiercelLog("[manager] running", identifier: identifier)
            progressExecuter?.execute(self)
        }
    }
    
    internal func updateProgress() {
        progressExecuter?.execute(self)
    }
    
    internal func didCancelOrRemove(_ url: URLConvertible) {
        guard let task = fetchTask(url) else { return }
        tasks.removeAll { $0.url == task.url}
        
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

        if shouldRemove() ||
            shouldCancel() ||
            shouldComplete() ||
            shouldSuspend() {

            invalidateTimer()
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

    @discardableResult
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

let refreshInterval: Double = 0.8
// MARK: - info
extension SessionManager {
    private func createTimer() {
        if timer == nil {
            timer = DispatchSource.makeTimerSource(flags: .strict, queue: operationQueue)
            timer?.schedule(deadline: .now(), repeating: refreshInterval)
            timer?.setEventHandler(handler: { [weak self] in
                guard let self = self else { return }
                self.updateSpeedAndTimeRemaining()
            })
            timer?.resume()
        }
    }

    private func invalidateTimer() {
        timer?.cancel()
        timer = nil
    }

    internal func updateSpeedAndTimeRemaining() {

        var result: Int64 = 0
        let interval = refreshInterval
        tasks.forEach({ (task) in
            if task.status == .running {
                task.updateSpeedAndTimeRemaining(interval)
                result += task.speed
            }
        })
        
        speed = result
        updateTimeRemaining()
        
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
        return operationQueue.sync {
            progressExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            return self
        }
    }
    
    @discardableResult
    public func success(onMainQueue: Bool = true, _ handler: @escaping Handler<SessionManager>) -> Self {
        operationQueue.sync {
            successExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        }
        operationQueue.async {
            if self.status == .succeeded {
                self.successExecuter?.execute(self)
            }
        }
        return self
    }
    
    @discardableResult
    public func failure(onMainQueue: Bool = true, _ handler: @escaping Handler<SessionManager>) -> Self {
        operationQueue.sync {
            failureExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        }
        operationQueue.async {
            if self.status == .suspended ||
                self.status == .canceled ||
                self.status == .removed ||
                self.status == .failed  {
                self.failureExecuter?.execute(self)
            }
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


