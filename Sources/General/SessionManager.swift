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
    
    enum MaintainTasksAction {
        case append(DownloadTask)
        case remove(DownloadTask)
        case succeeded(DownloadTask)
        case appendRunningTasks(DownloadTask)
        case removeRunningTasks(DownloadTask)
    }
    
    public let operationQueue: DispatchQueue
    
    public let cache: Cache
    
    public let identifier: String
    
    public var completionHandler: (() -> Void)?
    
    private var timer: DispatchSourceTimer?
    
    private var session: URLSession?
    
    private var shouldCreatSession: Bool = false
    
    private var restartTasks: [DownloadTask] = []

    public var configuration: SessionConfiguration {
        get { mutableState.configuration }
        set {
            var oldMaxConcurrentTasksLimit: Int = 0
            $mutableState.write {
                oldMaxConcurrentTasksLimit = $0.configuration.maxConcurrentTasksLimit
                $0.configuration = newValue
            }
            operationQueue.async {
                if !self.shouldCreatSession {
                    self.shouldCreatSession = true
                    self.$mutableState.read {
                        if $0.status == .running {
                            if $0.configuration.maxConcurrentTasksLimit <= oldMaxConcurrentTasksLimit {
                                self.restartTasks = $0.runningTasks + $0.tasks.filter { $0.status == .waiting }
                            } else {
                                self.restartTasks = $0.tasks.filter { $0.status == .waiting || $0.status == .running }
                            }
                            self.totalSuspend()
                        } else {
                            self.session?.invalidateAndCancel()
                            self.session = nil
                        }
                    }
                }
            }
        }
    }
    
    private struct MutableState {
        var logger: Logable
        var isControlNetworkActivityIndicator: Bool = true
        var configuration: SessionConfiguration
        var status: Status = .waiting
        var tasks: [DownloadTask] = []
        var taskMap: [URL: DownloadTask] = [URL: DownloadTask]()
        var urlMap: [URL: URL] = [URL: URL]()
        var runningTasks: [DownloadTask] = []
        var succeededTasks: [DownloadTask] = []
        var speed: Int64 = 0
        var timeRemaining: Int64 = 0
        
        var progressExecuter: Executer<SessionManager>?
        var successExecuter: Executer<SessionManager>?
        var failureExecuter: Executer<SessionManager>?
        var completionExecuter: Executer<SessionManager>?
        var controlExecuter: Executer<SessionManager>?
    }
    
    @Protected
    private var mutableState: MutableState
    
    public var logger: Logable {
        mutableState.logger
    }
    
    public var isControlNetworkActivityIndicator: Bool {
        get { mutableState.isControlNetworkActivityIndicator }
        set { mutableState.isControlNetworkActivityIndicator = newValue  }
    }
    
    
    public var canRunImmediately: Bool {
        $mutableState.read { $0.runningTasks.count < $0.configuration.maxConcurrentTasksLimit }
    }
    
    public var status: Status {
        mutableState.status
    }
    
    public var tasks: [DownloadTask] {
        mutableState.tasks
    }
    
    public var succeededTasks: [DownloadTask] {
        mutableState.succeededTasks
    }
    
    private let _progress = Progress()
    public var progress: Progress {
        $mutableState.read {
            _progress.completedUnitCount = $0.tasks.reduce(0, { $0 + $1.progress.completedUnitCount })
            _progress.totalUnitCount = $0.tasks.reduce(0, { $0 + $1.progress.totalUnitCount })
        }
        return _progress
    }
    
    public var speed: Int64 {
        mutableState.speed
    }
    
    public var speedString: String {
        speed.tr.convertSpeedToString()
    }
    
    public var timeRemaining: Int64 {
        mutableState.timeRemaining
    }
    
    public var timeRemainingString: String {
        timeRemaining.tr.convertTimeToString()
    }
    
    private var progressExecuter: Executer<SessionManager>? {
        get { mutableState.progressExecuter }
        set { mutableState.progressExecuter = newValue }
    }
    
    private var successExecuter: Executer<SessionManager>? {
        get { mutableState.successExecuter }
        set { mutableState.successExecuter = newValue }
    }
    
    private var failureExecuter: Executer<SessionManager>? {
        get { mutableState.failureExecuter }
        set { mutableState.failureExecuter = newValue }
    }
    
    private var completionExecuter: Executer<SessionManager>? {
        get { mutableState.completionExecuter }
        set { mutableState.completionExecuter = newValue }
    }
    
    private var controlExecuter: Executer<SessionManager>? {
        get { mutableState.controlExecuter }
        set { mutableState.controlExecuter = newValue }
    }
    
    
    
    public init(_ identifier: String,
                configuration: SessionConfiguration,
                logger: Logable? = nil,
                cache: Cache? = nil,
                operationQueue: DispatchQueue = DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue",
                                                              autoreleaseFrequency: .workItem)) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.Daniels.Tiercel"
        self.identifier = "\(bundleIdentifier).\(identifier)"
        let logger = logger ?? Logger(identifier: "\(self.identifier)", option: .default)
        mutableState = MutableState(logger: logger,
                                    configuration: configuration)
        self.operationQueue = operationQueue
        self.cache = cache ?? Cache(identifier)
        self.cache.logger = logger
        self.cache.retrieveAllTasks(with: operationQueue).forEach { maintainTasks(with: .append($0)) }
        log(.sessionManager(self, message: "retrieveTasks"))
        $mutableState.write { state in
            state.tasks.forEach {
                $0.delegate = self
                state.urlMap[$0.currentURL] = $0.url
            }
            state.succeededTasks = state.tasks.filter { $0.status == .succeeded }
        }
        operationQueue.sync {
            shouldCreatSession = true
            createSession()
            restoreStatus()
        }
    }
    
    deinit {
        invalidate()
    }
    
    public func invalidate() {
        operationQueue.async {
            self.session?.invalidateAndCancel()
            self.session = nil
            self.invalidateTimer()
        }
    }
    
    
    private func createSession(_ completion: (() -> ())? = nil) {
        dispatchPrecondition(condition: .onQueue(operationQueue))
        guard shouldCreatSession else { return }
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
        $mutableState.read { state in
            sessionConfiguration.timeoutIntervalForRequest = state.configuration.timeoutIntervalForRequest
            sessionConfiguration.httpMaximumConnectionsPerHost = 100000
            sessionConfiguration.allowsCellularAccess = state.configuration.allowsCellularAccess
            if #available(iOS 13, macOS 10.15, *) {
                sessionConfiguration.allowsConstrainedNetworkAccess = state.configuration.allowsConstrainedNetworkAccess
                sessionConfiguration.allowsExpensiveNetworkAccess = state.configuration.allowsExpensiveNetworkAccess
            }
        }
        let sessionDelegate = SessionDelegate()
        sessionDelegate.stateProvider = self
        let delegateQueue = OperationQueue(maxConcurrentOperationCount: 1,
                                           underlyingQueue: operationQueue,
                                           name: "com.Tiercel.SessionManager.delegateQueue")
        session = URLSession(configuration: sessionConfiguration,
                             delegate: sessionDelegate,
                             delegateQueue: delegateQueue)
        shouldCreatSession = false
        completion?()
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
                         fileName: String? = nil,
                         onMainQueue: Bool = true,
                         handler: Handler<DownloadTask>? = nil) -> DownloadTask? {
        do {
            let validURL = try url.asURL()
            var task: DownloadTask!
            operationQueue.sync {
                task = fetchTask(validURL)
                if let task = task {
                    task.update(headers, newFileName: fileName)
                } else {
                    task = DownloadTask(validURL,
                                        headers: headers,
                                        fileName: fileName,
                                        cache: cache,
                                        operationQueue: operationQueue)
                    task.delegate = self
                    maintainTasks(with: .append(task))
                }
                storeTasks()
                _start(task, onMainQueue: onMainQueue, handler: handler)
            }
            return task
        } catch {
            log(.error(error, message: "create dowloadTask failed"))
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
                              headersArray: [[String: String]]? = nil,
                              fileNames: [String]? = nil,
                              onMainQueue: Bool = true,
                              handler: Handler<SessionManager>? = nil) -> [DownloadTask] {
        if let headersArray = headersArray,
           headersArray.count != 0 && headersArray.count != urls.count {
            log(.error(TiercelError.headersMatchFailed, message: "create multiple dowloadTasks failed"))
            return [DownloadTask]()
        }
        
        if let fileNames = fileNames,
           fileNames.count != 0 && fileNames.count != urls.count {
            log(.error(TiercelError.fileNamesMatchFailed, message: "create multiple dowloadTasks failed"))
            return [DownloadTask]()
        }
        
        var urlSet = Set<URL>()
        var uniqueTasks = [DownloadTask]()
        
        operationQueue.sync {
            for (index, url) in urls.enumerated() {
                guard let validURL = try? url.asURL() else {
                    log(.error(TiercelError.invalidURL(url: url), message: "create dowloadTask failed"))
                    continue
                }
                guard urlSet.insert(validURL).inserted else {
                    log(.error(TiercelError.duplicateURL(url: url), message: "create dowloadTask failed"))
                    continue
                }
                let fileName = fileNames?.safeObject(at: index)
                let headers = headersArray?.safeObject(at: index)
                
                var task: DownloadTask!
                task = fetchTask(validURL)
                if let task = task {
                    task.update(headers, newFileName: fileName)
                } else {
                    task = DownloadTask(validURL,
                                        headers: headers,
                                        fileName: fileName,
                                        cache: cache,
                                        operationQueue: operationQueue)
                    task.delegate = self
                    maintainTasks(with: .append(task))
                }
                uniqueTasks.append(task)
            }
            storeTasks()
            Executer(onMainQueue: onMainQueue, handler: handler).execute(self)
            // TODO: - 待优化
            operationQueue.async {
                uniqueTasks.forEach {
                    if $0.status != .succeeded {
                        self._start($0)
                    }
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
            return $mutableState.read { $0.taskMap[validURL] }
        } catch {
            log(.error(TiercelError.invalidURL(url: url), message: "fetch task failed"))
            return nil
        }
    }
    
    func mapTask(_ currentURL: URL) -> DownloadTask? {
        $mutableState.read {
            let url = $0.urlMap[currentURL] ?? currentURL
            return $0.taskMap[url]
        }
    }
    
    
    
    /// 开启任务
    /// 会检查存放下载完成的文件中是否存在跟fileName一样的文件
    /// 如果存在则不会开启下载，直接调用task的successHandler
    public func start(_ url: URLConvertible, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            self._start(url, onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func start(_ task: DownloadTask, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            self._start(task.url, onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    private func _start(_ url: URLConvertible, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        guard let task = self.fetchTask(url) else {
            log(.error(TiercelError.fetchDownloadTaskFailed(url: url), message: "can't start downloadTask"))
            return
        }
        _start(task, onMainQueue: onMainQueue, handler: handler)
    }
    
    private func _start(_ task: DownloadTask, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        dispatchPrecondition(condition: .onQueue(operationQueue))
        task.mutableState.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        didStart()
        if !shouldCreatSession, let session = session {
            task.start(using: session, immediately: canRunImmediately)
        } else {
            task.suspend()
            if restartTasks.contains(task) {
                restartTasks.append(task)
            }
        }
    }
    
    
    /// 暂停任务，会触发sessionDelegate的完成回调
    public func suspend(_ url: URLConvertible, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(url) else {
                self.log(.error(TiercelError.fetchDownloadTaskFailed(url: url), message: "can't suspend downloadTask"))
                return
            }
            task.suspend(onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func suspend(_ task: DownloadTask, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            guard let _ = self.fetchTask(task.url) else {
                self.log(.error(TiercelError.fetchDownloadTaskFailed(url: task.url), message: "can't suspend downloadTask"))
                return
            }
            task.suspend(onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    /// 取消任务
    /// 不会对已经完成的任务造成影响
    /// 其他状态的任务都可以被取消，被取消的任务会被移除
    /// 会删除还没有下载完成的缓存文件
    /// 会触发sessionDelegate的完成回调
    public func cancel(_ url: URLConvertible, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(url) else {
                self.log(.error(TiercelError.fetchDownloadTaskFailed(url: url), message: "can't cancel downloadTask"))
                return
            }
            task.cancel(onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func cancel(_ task: DownloadTask, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            guard let _ = self.fetchTask(task.url) else {
                self.log(.error(TiercelError.fetchDownloadTaskFailed(url: task.url), message: "can't cancel downloadTask"))
                return
            }
            task.cancel(onMainQueue: onMainQueue, handler: handler)
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
    public func remove(_ url: URLConvertible, completely: Bool = false, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(url) else {
                self.log(.error(TiercelError.fetchDownloadTaskFailed(url: url), message: "can't remove downloadTask"))
                return
            }
            task.remove(completely: completely, onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func remove(_ task: DownloadTask, completely: Bool = false, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            guard let _ = self.fetchTask(task.url) else {
                self.log(.error(TiercelError.fetchDownloadTaskFailed(url: task.url),
                                message: "can't remove downloadTask"))
                return
            }
            task.remove(completely: completely, onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func moveTask(at sourceIndex: Int, to destinationIndex: Int) {
        operationQueue.sync {
            let range = (0..<tasks.count)
            guard range.contains(sourceIndex) && range.contains(destinationIndex) else {
                log(.error(TiercelError.indexOutOfRange,
                           message: "move task failed, sourceIndex: \(sourceIndex), destinationIndex: \(destinationIndex)"))
                return
            }
            if sourceIndex == destinationIndex {
                return
            }
            $mutableState.write {
                let task = $0.tasks[sourceIndex]
                $0.tasks.remove(at: sourceIndex)
                $0.tasks.insert(task, at: destinationIndex)
            }
        }
    }
    
}

// MARK: - total tasks control
extension SessionManager {
    
    public func totalStart(onMainQueue: Bool = true, handler: Handler<SessionManager>? = nil) {
        operationQueue.async {
            self.tasks.forEach { task in
                if task.status != .succeeded {
                    self._start(task)
                }
            }
            Executer(onMainQueue: onMainQueue, handler: handler).execute(self)
        }
    }
    
    public func totalSuspend(onMainQueue: Bool = true, handler: Handler<SessionManager>? = nil) {
        operationQueue.async {
            guard self.status == .running || self.status == .waiting else { return }
            self.$mutableState.write {
                $0.status = .willSuspend
                $0.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            }
            self.tasks.forEach { $0.suspend() }
        }
    }
    
    public func totalCancel(onMainQueue: Bool = true, handler: Handler<SessionManager>? = nil) {
        operationQueue.async {
            guard self.status != .succeeded && self.status != .canceled else { return }
            self.$mutableState.write {
                $0.status = .willCancel
                $0.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            }
            self.tasks.forEach { $0.cancel() }
        }
    }
    
    public func totalRemove(completely: Bool = false, onMainQueue: Bool = true, handler: Handler<SessionManager>? = nil) {
        operationQueue.async {
            guard self.status != .removed else { return }
            self.$mutableState.write {
                $0.status = .willRemove
                $0.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            }
            self.tasks.forEach { $0.remove(completely: completely) }
        }
    }
    
    public func tasksSort(by areInIncreasingOrder: (DownloadTask, DownloadTask) throws -> Bool) rethrows {
        try operationQueue.sync {
            try $mutableState.write {
                try $0.tasks.sort(by: areInIncreasingOrder)
            }
        }
    }
}


// MARK: - status handle
extension SessionManager {
    
    private func maintainTasks(with action: MaintainTasksAction) {
        
        switch action {
            case let .append(task):
                $mutableState.write { state in
                    state.tasks.append(task)
                    state.taskMap[task.url] = task
                    state.urlMap[task.currentURL] = task.url
                }
            case let .remove(task):
                $mutableState.write { state in
                    if state.status == .willRemove {
                        state.taskMap.removeValue(forKey: task.url)
                        state.urlMap.removeValue(forKey: task.currentURL)
                        if state.taskMap.values.isEmpty {
                            state.tasks.removeAll()
                            state.succeededTasks.removeAll()
                        }
                    } else if state.status == .willCancel {
                        state.taskMap.removeValue(forKey: task.url)
                        state.urlMap.removeValue(forKey: task.currentURL)
                        if state.taskMap.values.count == state.succeededTasks.count {
                            state.tasks = state.succeededTasks
                        }
                    } else {
                        state.taskMap.removeValue(forKey: task.url)
                        state.urlMap.removeValue(forKey: task.currentURL)
                        state.tasks.removeAll {
                            $0.url.absoluteString == task.url.absoluteString
                        }
                        if task.status == .removed {
                            state.succeededTasks.removeAll {
                                $0.url.absoluteString == task.url.absoluteString
                            }
                        }
                    }
                }
            case let .succeeded(task):
                $mutableState.write{ $0.succeededTasks.append(task) }
            case let .appendRunningTasks(task):
                $mutableState.write { state in
                    state.runningTasks.append(task)
                }
            case let .removeRunningTasks(task):
                $mutableState.write { state in
                    state.runningTasks.removeAll {
                        $0.url.absoluteString == task.url.absoluteString
                    }
                }
        }
    }
    
    private func updateUrlMapper(with task: DownloadTask) {
        $mutableState.write { $0.urlMap[task.currentURL] = task.url }
    }
    
    private func restoreStatus() {
        dispatchPrecondition(condition: .onQueue(operationQueue))
        if self.tasks.isEmpty {
            return
        }
        session?.getTasksWithCompletionHandler { [weak self] (dataTasks, uploadTasks, downloadTasks) in
            guard let self = self else { return }
            downloadTasks.forEach { downloadTask in
                if downloadTask.state == .running,
                   let currentURL = downloadTask.currentRequest?.url,
                   let task = self.mapTask(currentURL) {
                    self.didStart()
                    task.restoreRunningStatus(with: downloadTask)
                    self.taskDidStart(task)
                }
            }
            //  处理mananger状态
            if !self.shouldComplete() {
                self.shouldSuspend()
            }
        }
    }
    
    
    private func shouldComplete() -> Bool {
        
        let isSucceeded = self.tasks.allSatisfy { $0.status == .succeeded }
        let isCompleted = isSucceeded ? isSucceeded :
        self.tasks.allSatisfy { $0.status == .succeeded || $0.status == .failed }
        guard isCompleted else { return false }
        
        if status == .succeeded || status == .failed {
            return true
        }
        mutableState.timeRemaining = 0
        progressExecuter?.execute(self)
        let status: Status = isSucceeded ? .succeeded : .failed
        mutableState.status = status
        didChangeStatus(to: status)
        executeCompletion(isSucceeded)
        return true
    }
    
    
    
    private func shouldSuspend() {
        dispatchPrecondition(condition: .onQueue(operationQueue))
        let isSuspended = tasks.allSatisfy { $0.status == .suspended || $0.status == .succeeded || $0.status == .failed }
        
        if isSuspended {
            if status == .suspended {
                return
            }
            mutableState.status = .suspended
            didChangeStatus(to: .suspended)
            executeControl()
            executeCompletion(false)
            if shouldCreatSession {
                session?.invalidateAndCancel()
                session = nil
            }
        }
    }
    
    private func didStart() {
        if status != .running {
            if isControlNetworkActivityIndicator {
                DispatchQueue.tr.executeOnMain {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = true
                }
            }
            createTimer()
            mutableState.status = .running
            didChangeStatus(to: .running)
            progressExecuter?.execute(self)
        }
    }
    
    private func updateProgress() {
        progressExecuter?.execute(self)
        NotificationCenter.default.postNotification(name: SessionManager.runningNotification, sessionManager: self)
    }
    
    
    private func storeTasks() {
        cache.storeTasks(tasks)
    }
    
    private func determineStatus(fromRunningTask: Bool) {
        dispatchPrecondition(condition: .onQueue(operationQueue))
        
        // removed
        if status == .willRemove {
            if tasks.isEmpty {
                mutableState.status = .removed
                didChangeStatus(to: .removed)
                executeControl()
                ending(false)
            }
            return
        }
        
        // canceled
        if status == .willCancel {
            let succeededTasksCount = mutableState.taskMap.values.count
            if tasks.count == succeededTasksCount {
                mutableState.status = .canceled
                didChangeStatus(to: .canceled)
                executeControl()
                ending(false)
            }
            return
        }
        
        // completed
        let isCompleted = tasks.allSatisfy { $0.status == .succeeded || $0.status == .failed }
        
        if isCompleted {
            if status == .succeeded || status == .failed {
                storeTasks()
                return
            }
            mutableState.timeRemaining = 0
            progressExecuter?.execute(self)
            let isSucceeded = tasks.allSatisfy { $0.status == .succeeded }
            let status: Status = isSucceeded ? .succeeded : .failed
            mutableState.status = status
            didChangeStatus(to: status)
            ending(isSucceeded)
            return
        }
        
        // suspended
        let isSuspended = tasks.allSatisfy {
            $0.status == .suspended ||
            $0.status == .succeeded ||
            $0.status == .failed
        }
        
        if isSuspended {
            if status == .suspended {
                storeTasks()
                return
            }
            mutableState.status = .suspended
            didChangeStatus(to: .suspended)
            if shouldCreatSession {
                session?.invalidateAndCancel()
                session = nil
            } else {
                executeControl()
                ending(false)
            }
            return
        }
        
        if status == .willSuspend {
            return
        }
        
        storeTasks()
        
        if fromRunningTask {
            // next task
            operationQueue.async {
                self.startNextTask()
            }
        }
    }
    
    private func ending(_ isSucceeded: Bool) {
        executeCompletion(isSucceeded)
        storeTasks()
        invalidateTimer()
    }
    
    
    private func startNextTask() {
        dispatchPrecondition(condition: .onQueue(operationQueue))
        guard let session = session,
              let waitingTask = tasks.first (where: { $0.status == .waiting })
        else { return }
        waitingTask.start(using: session, immediately: canRunImmediately)
    }
}

// MARK: - info
extension SessionManager {
        
    private func createTimer() {
        dispatchPrecondition(condition: .onQueue(operationQueue))
        if timer == nil {
            timer = DispatchSource.makeTimerSource(flags: .strict, queue: operationQueue)
            timer?.schedule(deadline: .now(), repeating: 1)
            timer?.setEventHandler(handler: { [weak self] in
                guard let self = self else { return }
                self.updateSpeedAndTimeRemaining()
            })
            timer?.resume()
        }
    }
    
    private func invalidateTimer() {
        dispatchPrecondition(condition: .onQueue(operationQueue))
        timer?.cancel()
        timer = nil
    }
    
    private func updateSpeedAndTimeRemaining() {
        let speed: Int64 = $mutableState.read { state in
            state.runningTasks.reduce(Int64(0), {
                $1.updateSpeedAndTimeRemaining()
                return $0 + $1.speed
            })
        }
        updateTimeRemaining(speed)
    }
    
    private func updateTimeRemaining(_ speed: Int64) {
        var timeRemaining: Double
        if speed != 0 {
            timeRemaining = (Double(progress.totalUnitCount) - Double(progress.completedUnitCount)) / Double(speed)
            if timeRemaining >= 0.8 && timeRemaining < 1 {
                timeRemaining += 1
            }
        } else {
            timeRemaining = 0
        }
        $mutableState.write {
            $0.speed = speed
            $0.timeRemaining = Int64(timeRemaining)
        }
    }
    
    private func didChangeStatus(to newValue: Status) {
        log(.sessionManager(self, message: newValue.rawValue))
        if newValue == .canceled || newValue == .removed || newValue == .succeeded || newValue == .failed {
            if isControlNetworkActivityIndicator {
                DispatchQueue.tr.executeOnMain {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
            }
        }
    }
    
    private func log(_ type: LogType) {
        logger.log(type)
    }
}

// MARK: - closure
extension SessionManager {
    @discardableResult
    public func progress(onMainQueue: Bool = true, handler: @escaping Handler<SessionManager>) -> Self {
        progressExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        return self
    }
    
    @discardableResult
    public func success(onMainQueue: Bool = true, handler: @escaping Handler<SessionManager>) -> Self {
        successExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        return self
    }
    
    @discardableResult
    public func failure(onMainQueue: Bool = true, handler: @escaping Handler<SessionManager>) -> Self {
        failureExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        return self
    }
    
    @discardableResult
    public func completion(onMainQueue: Bool = true, handler: @escaping Handler<SessionManager>) -> Self {
        completionExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        return self
    }
    
    private func executeCompletion(_ isSucceeded: Bool) {
        if let completionExecuter = completionExecuter {
            completionExecuter.execute(self)
        } else if isSucceeded {
            successExecuter?.execute(self)
        } else {
            failureExecuter?.execute(self)
        }
        NotificationCenter.default.postNotification(name: SessionManager.didCompleteNotification, sessionManager: self)
    }
    
    private func executeControl() {
        controlExecuter?.execute(self)
        controlExecuter = nil
    }
}

// MARK: - TaskDelegate
extension SessionManager: TaskDelegate {
    public func task<TaskType>(_ task: Task<TaskType>, didChangeStatusTo newValue: Status) {
        if let task = task as? DownloadTask {
            log(.downloadTask(task, message: newValue.rawValue))
        }
    }
    
    public func taskDidStart<TaskType>(_ task: Task<TaskType>) {
        if let task = task as? DownloadTask {
            maintainTasks(with: .appendRunningTasks(task))
            storeTasks()
        }
    }
    
    public func taskDidCancelOrRemove<TaskType>(_ task: Task<TaskType>) {
        if let task = task as? DownloadTask {
            maintainTasks(with: .remove(task))
            
            // 处理使用单个任务操作移除最后一个task时，manager状态
            $mutableState.write {
                if $0.tasks.isEmpty {
                    if task.status == .canceled {
                        $0.status = .willCancel
                    }
                    if task.status == .removed {
                        $0.status = .willRemove
                    }
                }
            }
        }
    }
    
    public func taskDidCompleteFromRunning<TaskType>(_ task: Task<TaskType>) {
        if let task = task as? DownloadTask {
            maintainTasks(with: .removeRunningTasks(task))
        }
    }
    
    public func task<TaskType>(_ task: Task<TaskType>, didSucceed fromRunning: Bool) {
        if let task = task as? DownloadTask {
            maintainTasks(with: .succeeded(task))
        }
        determineStatus(fromRunningTask: fromRunning)
    }
    
    public func task<TaskType>(_ task: Task<TaskType>, didDetermineStatus fromRunning: Bool) {
        determineStatus(fromRunningTask: fromRunning)
    }
    
    public func taskDidUpdateCurrentURL<TaskType>(_ task: Task<TaskType>) {
        if let task = task as? DownloadTask {
            updateUrlMapper(with: task)
        }
    }
    
    public func taskDidUpdateProgress<TaskType>(_ task: Task<TaskType>) {
        updateProgress()
    }
    
}

extension SessionManager: DownloadTaskDelegate {
    public func downloadTaskFileExists(_ task: DownloadTask) {
        log(.downloadTask(task, message: "file already exists"))
    }
    
    public func downloadTaskWillValidateFile(_ task: DownloadTask) {
        storeTasks()
    }
    
    public func downloadTask(_ task: DownloadTask, didValidateFile result: Result<Bool, FileChecksumHelper.FileVerificationError>) {
        switch result {
            case .success:
                log(.downloadTask(task, message: "file validation successful"))
            case let .failure(error):
                log(.error(error, message: "file validation failed, url: \(task.url)"))
        }
        storeTasks()
    }
    
}

// MARK: - SessionStateProvider
extension SessionManager: SessionStateProvider {
    func task<TaskType, R>(for url: URL, as type: R.Type) -> R? where R : Task<TaskType> {
        return mapTask(url) as? R
    }
    
    func log(_ error: Error, message: String) {
        log(.error(error, message: message))
    }
    
    func didBecomeInvalidation(withError error: Error?) {
        createSession { [weak self] in
            guard let self = self else { return }
            self.restartTasks.forEach { self._start($0) }
            self.restartTasks.removeAll()
        }
    }
    
    func didFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.tr.executeOnMain {
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
}
