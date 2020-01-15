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

    public let operationQueue: DispatchQueue
    
    public let cache: Cache
    
    public let identifier: String
    
    public var completionHandler: (() -> Void)?

    public var configuration: SessionConfiguration {
        get { protectedState.directValue.configuration }
        set {
            operationQueue.sync {
                protectedState.write {
                    $0.configuration = newValue
                    if $0.status == .running {
                        totalSuspend()
                    }
                }
            }
        }
    }
    
    private struct State {
        var logger: Logable
        var isControlNetworkActivityIndicator: Bool = true
        var configuration: SessionConfiguration {
            didSet {
                guard !shouldCreatSession else { return }
                shouldCreatSession = true
                if status == .running {
                    runningTasks = tasks.filter { $0.status == .running }
                    waitingTasks = tasks.filter { $0.status == .waiting }
                } else {
                    session?.invalidateAndCancel()
                    session = nil
                }
            }
        }
        var session: URLSession?
        var shouldCreatSession: Bool = false
        var timer: DispatchSourceTimer?
        var status: Status = .waiting
        var tasks: [DownloadTask] = []
        var taskMapper: [String: DownloadTask] = [String: DownloadTask]()
        var urlMapper: [URL: URL] = [URL: URL]()
        var runningTasks: [DownloadTask] = []
        var waitingTasks: [DownloadTask] = []
        var speed: Int64 = 0
        var timeRemaining: Int64 = 0
        
        var progressExecuter: Executer<SessionManager>?
        var successExecuter: Executer<SessionManager>?
        var failureExecuter: Executer<SessionManager>?
        var completionExecuter: Executer<SessionManager>?
        var controlExecuter: Executer<SessionManager>?
    }
    
    
    private let protectedState: Protector<State>

    public var logger: Logable {
        get { protectedState.directValue.logger }
        set { protectedState.write { $0.logger = newValue } }
    }
    
    public var isControlNetworkActivityIndicator: Bool {
        get { protectedState.directValue.isControlNetworkActivityIndicator }
        set { protectedState.write { $0.isControlNetworkActivityIndicator = newValue } }
    }
    
    internal var shouldRun: Bool {
        return tasks.filter { $0.status == .running }.count < configuration.maxConcurrentTasksLimit
    }
    
    private var session: URLSession? {
        get { protectedState.directValue.session }
        set { protectedState.write { $0.session = newValue } }
    }
    
    private var shouldCreatSession: Bool {
        get { protectedState.directValue.shouldCreatSession }
        set { protectedState.write { $0.shouldCreatSession = newValue } }
    }

    
    private var timer: DispatchSourceTimer? {
        get { protectedState.directValue.timer }
        set { protectedState.write { $0.timer = newValue } }
    }

    
    public private(set) var status: Status {
        get { protectedState.directValue.status }
        set {
            protectedState.write { $0.status = newValue }
            if newValue == .willSuspend || newValue == .willCancel || newValue == .willRemove {
                return
            }
            log(.sessionManager(newValue.rawValue, manager: self))
        }
    }
    
    
    public private(set) var tasks: [DownloadTask] {
        get { protectedState.directValue.tasks }
        set { protectedState.write { $0.tasks = newValue } }
    }
    
    private var runningTasks: [DownloadTask] {
        get { protectedState.directValue.runningTasks }
        set { protectedState.write { $0.runningTasks = newValue } }
    }
    
    private var waitingTasks: [DownloadTask] {
        get { protectedState.directValue.waitingTasks }
        set { protectedState.write { $0.waitingTasks = newValue } }
    }

    public var succeededTasks: [DownloadTask] {
        return tasks.filter { $0.status == .succeeded }
    }

    private let _progress = Progress()
    public var progress: Progress {
        _progress.completedUnitCount = tasks.reduce(0, { $0 + $1.progress.completedUnitCount })
        _progress.totalUnitCount = tasks.reduce(0, { $0 + $1.progress.totalUnitCount })
        return _progress
    }

    public private(set) var speed: Int64 {
        get { protectedState.directValue.speed }
        set { protectedState.write { $0.speed = newValue } }
    }

    public var speedString: String {
        speed.tr.convertSpeedToString()
    }
    
    
    public private(set) var timeRemaining: Int64 {
        get { protectedState.directValue.timeRemaining }
        set { protectedState.write { $0.timeRemaining = newValue } }
    }

    public var timeRemainingString: String {
        timeRemaining.tr.convertTimeToString()
    }
    
    private var progressExecuter: Executer<SessionManager>? {
        get { protectedState.directValue.progressExecuter }
        set { protectedState.write { $0.progressExecuter = newValue } }
    }
    
    private var successExecuter: Executer<SessionManager>? {
        get { protectedState.directValue.successExecuter }
        set { protectedState.write { $0.successExecuter = newValue } }
    }
    
    private var failureExecuter: Executer<SessionManager>? {
        get { protectedState.directValue.failureExecuter }
        set { protectedState.write { $0.failureExecuter = newValue } }
    }
    
    private var completionExecuter: Executer<SessionManager>? {
        get { protectedState.directValue.completionExecuter }
        set { protectedState.write { $0.completionExecuter = newValue } }
    }
    
    private var controlExecuter: Executer<SessionManager>? {
        get { protectedState.directValue.controlExecuter }
        set { protectedState.write { $0.controlExecuter = newValue } }
    }

    
    
    public init(_ identifier: String,
                configuration: SessionConfiguration,
                logger: Logable? = nil,
                cache: Cache? = nil,
                operationQueue: DispatchQueue = DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue")) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.Daniels.Tiercel"
        self.identifier = "\(bundleIdentifier).\(identifier)"
        protectedState = Protector(
            State(logger: logger ?? Logger(identifier: "\(bundleIdentifier).\(identifier)", option: .default),
                  configuration: configuration)
        )
        self.operationQueue = operationQueue
        self.cache = cache ?? Cache(identifier)
        self.cache.manager = self
        self.cache.retrieveAllTasks().forEach { updateTasks(with: .append($0)) }
        log(.sessionManager("retrieveTasks", manager: self))
        protectedState.write { state in
            state.tasks.forEach {
                $0.manager = self
                $0.operationQueue = operationQueue
                state.urlMapper[$0.currentURL] = $0.url
            }
            state.shouldCreatSession = true
        }
        operationQueue.sync {
            createSession()
            restoreStatus()
        }
    }
    
    deinit {
        invalidate()
    }

    public func invalidate() {
        session?.invalidateAndCancel()
        session = nil
        cache.invalidate()
        invalidateTimer()
    }


    private func createSession(_ completion: (() -> ())? = nil) {
        guard shouldCreatSession else { return }
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeoutIntervalForRequest
        sessionConfiguration.httpMaximumConnectionsPerHost = 100000
        sessionConfiguration.allowsCellularAccess = configuration.allowsCellularAccess
        if #available(iOS 13, *) {
            sessionConfiguration.allowsConstrainedNetworkAccess = configuration.allowsConstrainedNetworkAccess
            sessionConfiguration.allowsExpensiveNetworkAccess = configuration.allowsExpensiveNetworkAccess
        }
        let sessionDelegate = SessionDelegate()
        sessionDelegate.manager = self
        let delegateQueue = OperationQueue(maxConcurrentOperationCount: 1,
                                           underlyingQueue: operationQueue,
                                           name: "com.Tiercel.SessionManager.delegateQueue")
        protectedState.write {
            let session = URLSession(configuration: sessionConfiguration,
                                     delegate: sessionDelegate,
                                     delegateQueue: delegateQueue)
            $0.session = session
            $0.tasks.forEach { $0.session = session }
            $0.shouldCreatSession = false
        }
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
                         fileName: String? = nil) -> DownloadTask? {
        do {
            let validURL = try url.asURL()
            var task: DownloadTask?
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
                    task?.manager = self
                    task?.session = session
                    updateTasks(with: .append(task!))
                }
                cache.storeTasks(tasks)
            }
            start(task!)
            return task
        } catch {
            log(.error("create dowloadTask failed", error: error))
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
                              fileNames: [String]? = nil) -> [DownloadTask] {
        if let headersArray = headersArray,
            headersArray.count != 0 && headersArray.count != urls.count {
            log(.error("create multiple dowloadTasks failed", error: TiercelError.headersMatchFailed))
            return [DownloadTask]()
        }
        
        if let fileNames = fileNames,
            fileNames.count != 0 && fileNames.count != urls.count {
            log(.error("create multiple dowloadTasks failed", error: TiercelError.fileNamesMatchFailed))
            return [DownloadTask]()
        }

        var urlSet = Set<URL>()
        var uniqueTasks = [DownloadTask]()

        operationQueue.sync {
            for (index, url) in urls.enumerated() {
                let fileName = fileNames?.safeObject(at: index)
                let headers = headersArray?.safeObject(at: index)

                guard let validURL = try? url.asURL() else {
                    log(.error("create dowloadTask failed", error: TiercelError.invalidURL(url: url)))
                    continue
                }
                guard urlSet.insert(validURL).inserted else {
                    log(.error("create dowloadTask failed", error: TiercelError.duplicateURL(url: url)))
                    continue
                }

                var task: DownloadTask?
                task = fetchTask(validURL)
                if let task = task {
                    task.update(headers, newFileName: fileName)
                } else {
                    task = DownloadTask(validURL,
                                        headers: headers,
                                        fileName: fileName,
                                        cache: cache,
                                        operationQueue: operationQueue)
                    task?.manager = self
                    task?.session = session
                    updateTasks(with: .append(task!))
                    uniqueTasks.append(task!)
                }
            }
            cache.storeTasks(tasks)
        }
        uniqueTasks.forEach { start($0) }
        return uniqueTasks
    }
}

// MARK: - single task control
extension SessionManager {
    
    public func fetchTask(_ url: URLConvertible) -> DownloadTask? {
        do {
            let validURL = try url.asURL()
            return protectedState.read { $0.taskMapper[validURL.absoluteString] }
        } catch {
            log(.error("fetch task failed", error: TiercelError.invalidURL(url: url)))
            return nil
        }
    }
    
    internal func mapTask(_ currentURL: URL) -> DownloadTask? {
        protectedState.read {
            let url = $0.urlMapper[currentURL] ?? currentURL
            return $0.taskMapper[url.absoluteString]
        }
    }

    
    
    /// 开启任务
    /// 会检查存放下载完成的文件中是否存在跟fileName一样的文件
    /// 如果存在则不会开启下载，直接调用task的successHandler
    public func start(_ url: URLConvertible) {
        operationQueue.sync {
            guard let task = self.fetchTask(url) else {
                self.log(.error("can't start downloadTask", error: TiercelError.fetchDownloadTaskFailed(url: url)))
                return
            }
            if !self.shouldCreatSession {
                task.prepareForDownload()
            } else {
                task.update(newStatus: .suspended)
                if !self.waitingTasks.contains(task) {
                    self.waitingTasks.append(task)
                }
            }
        }
    }
    
    public func start(_ task: DownloadTask) {
        operationQueue.sync {
            if !self.shouldCreatSession {
                task.prepareForDownload()
            } else {
                task.update(newStatus: .suspended)
                if !self.waitingTasks.contains(task) {
                    self.waitingTasks.append(task)
                }
            }
        }
    }

    
    /// 暂停任务，会触发sessionDelegate的完成回调
    public func suspend(_ url: URLConvertible, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(url) else {
                self.log(.error("can't suspend downloadTask", error: TiercelError.fetchDownloadTaskFailed(url: url)))
                return
            }
            task.suspend(onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func suspend(_ task: DownloadTask, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
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
                self.log(.error("can't cancel downloadTask", error: TiercelError.fetchDownloadTaskFailed(url: url)))
                return
            }
            task.cancel(onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func cancel(_ task: DownloadTask, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
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
                self.log(.error("can't remove downloadTask", error: TiercelError.fetchDownloadTaskFailed(url: url)))
                return
            }
            task.remove(completely: completely, onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func remove(_ task: DownloadTask, completely: Bool = false, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        operationQueue.async {
            task.remove(completely: completely, onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func moveTask(at sourceIndex: Int, to destinationIndex: Int) {
        operationQueue.sync {
            let range = (0..<tasks.count)
            guard range.contains(sourceIndex) && range.contains(destinationIndex) else {
                log(.error("move task failed, sourceIndex: \(sourceIndex), destinationIndex: \(destinationIndex)",
                                error: TiercelError.indexOutOfRange))
                return
            }
            protectedState.write {
                let task = $0.tasks[sourceIndex]
                $0.tasks.remove(at: sourceIndex)
                $0.tasks.insert(task, at: destinationIndex)
            }
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
    
    public func totalSuspend(onMainQueue: Bool = true, handler: Handler<SessionManager>? = nil) {
        operationQueue.async {
            guard self.status == .running || self.status == .waiting else { return }
            self.status = .willSuspend
            self.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            self.tasks.forEach { $0.suspend() }
        }

    }
    
    public func totalCancel(onMainQueue: Bool = true, handler: Handler<SessionManager>? = nil) {
        operationQueue.async {
            guard self.status != .succeeded && self.status != .canceled else { return }
            self.status = .willCancel
            self.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            self.tasks.forEach { $0.cancel() }
        }
    }
    
    public func totalRemove(completely: Bool = false, onMainQueue: Bool = true, handler: Handler<SessionManager>? = nil) {
        operationQueue.async {
            guard self.status != .removed else { return }
            self.status = .willRemove
            self.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            self.tasks.forEach { $0.remove(completely: completely) }
        }
    }
    
    public func tasksSort(by areInIncreasingOrder: (DownloadTask, DownloadTask) throws -> Bool) rethrows {
        try operationQueue.sync {
            try protectedState.write {
                try $0.tasks.sort(by: areInIncreasingOrder)
            }
        }
    }
}


// MARK: - status handle
extension SessionManager {

    private enum TasksUpdateAction {
        case append(DownloadTask)
        case remove(DownloadTask)
    }

    private func updateTasks(with action: TasksUpdateAction) {
        switch action {
        case let .append(task):
            protectedState.write { state in
                state.tasks.append(task)
                state.taskMapper[task.url.absoluteString] = task
                state.urlMapper[task.currentURL] = task.url
            }
        case let .remove(task):
            protectedState.write { state in
                state.tasks.removeAll {
                    $0.url.absoluteString == task.url.absoluteString
                }
                state.taskMapper.removeValue(forKey: task.url.absoluteString)
                state.urlMapper.removeValue(forKey: task.currentURL)
            }
        }
    }

    internal func updateUrlMapper(with task: DownloadTask) {
        protectedState.write { $0.urlMapper[task.currentURL] = task.url }
    }
    
    private func restoreStatus() {
        if self.tasks.isEmpty {
            return
        }
        session?.getTasksWithCompletionHandler { [weak self] (dataTasks, uploadTasks, downloadTasks) in
            guard let self = self else { return }
            var isRunning = false
            downloadTasks.forEach { downloadTask in
                if downloadTask.state == .running,
                    let currentURL = downloadTask.currentRequest?.url,
                    let task = self.mapTask(currentURL) {
                    task.update(newStatus: .running)
                    task.sessionTask = downloadTask
                    isRunning = true
                }
            }
            //  处理mananger状态
            if isRunning {
                self.didStart()
                return
            }
            
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
        timeRemaining = 0
        progressExecuter?.execute(self)
        status = isSucceeded ? .succeeded : .failed
        executeCompletion(isSucceeded)
        return true
    }
    


    private func shouldSuspend() {
        let isSuspended = tasks.allSatisfy { $0.status == .suspended || $0.status == .succeeded || $0.status == .failed }

        if isSuspended {
            if status == .suspended {
                return
            }
            status = .suspended
            executeControl()
            executeCompletion(false)
            if shouldCreatSession {
                session?.invalidateAndCancel()
                session = nil
            }
        }
    }
    
    internal func didStart() {
        if status != .running {
            createTimer()
            status = .running
            progressExecuter?.execute(self)
        }
    }
    
    internal func updateProgress() {
        if isControlNetworkActivityIndicator {
            DispatchQueue.tr.executeOnMain {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
        }
        progressExecuter?.execute(self)
    }
    
    internal func didCancelOrRemove(_ task: DownloadTask) {
        updateTasks(with: .remove(task))
        
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

    internal func storeTasks() {
        cache.storeTasks(tasks)
    }
    
    internal func determineStatus() {
        if isControlNetworkActivityIndicator {
            DispatchQueue.tr.executeOnMain {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }


        // removed
        if status == .willRemove {
            if tasks.isEmpty {
                status = .removed
                executeControl()
                executeCompletion(false)
                final()
            }
            return
        }
        
        // canceled
        let isSucceeded = tasks.allSatisfy { $0.status == .succeeded }
        
        if status == .willCancel {
            if isSucceeded {
                status = .canceled
                executeControl()
                executeCompletion(false)
                final()
                return
            }
            return
        }
        
        // completed
        let isCompleted = isSucceeded ? isSucceeded :
                            tasks.allSatisfy { $0.status == .succeeded || $0.status == .failed }
        
        if isCompleted {
            if status == .succeeded || status == .failed {
                return
            }
            timeRemaining = 0
            progressExecuter?.execute(self)
            status = isSucceeded ? .succeeded : .failed
            executeCompletion(isSucceeded)
            final()
            return
        }
        
        // suspended
        let isSuspended = tasks.allSatisfy { $0.status == .suspended ||
                                             $0.status == .succeeded ||
                                             $0.status == .failed }

        if isSuspended {
            if status == .suspended {
                return
            }
            status = .suspended
            executeControl()
            executeCompletion(false)
            if shouldCreatSession {
                session?.invalidateAndCancel()
                session = nil
            }
            final()
            return
        }
        
        if status == .willSuspend {
            return
        }
        
        cache.storeTasks(tasks)
        
        // next task
        startNextTask()
    }
    
    private func final() {
        cache.storeTasks(tasks)
        invalidateTimer()
    }
    
    
    private func startNextTask() {
        guard let waitingTask = tasks.first (where: { $0.status == .waiting }) else { return }
        waitingTask.prepareForDownload()
    }
}

// MARK: - info
extension SessionManager {

    static let refreshInterval: Double = 0.8

    private func createTimer() {
        if timer == nil {
            timer = DispatchSource.makeTimerSource(flags: .strict, queue: operationQueue)
            timer?.schedule(deadline: .now(), repeating: Self.refreshInterval)
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
        let speed = tasks.reduce(Int64(0), {
            if $1.status == .running {
                $1.updateSpeedAndTimeRemaining(Self.refreshInterval)
                return $0 + $1.speed
            } else {
                return $0
            }
        })
        updateTimeRemaining(speed)
    }
    
    private func updateTimeRemaining(_ speed: Int64) {
        var timeRemaining: Double
        if speed == 0 {
            timeRemaining = 0
        } else {
            timeRemaining = (Double(progress.totalUnitCount) - Double(progress.completedUnitCount)) / Double(speed)
            if (0.8..<1).contains(timeRemaining) {
                timeRemaining += 1
            }
        }
        self.speed = speed
        self.timeRemaining = Int64(timeRemaining)
    }



    internal func log(_ type: LogType) {
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
        if status == .succeeded  && completionExecuter == nil{
            operationQueue.async {
                self.successExecuter?.execute(self)
            }
        }
        return self
    }
    
    @discardableResult
    public func failure(onMainQueue: Bool = true, handler: @escaping Handler<SessionManager>) -> Self {
        failureExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        if completionExecuter == nil &&
            (status == .suspended ||
            status == .canceled ||
            status == .removed ||
            status == .failed) {
            operationQueue.async {
                self.failureExecuter?.execute(self)
            }
        }
        return self
    }
    
    @discardableResult
    public func completion(onMainQueue: Bool = true, handler: @escaping Handler<SessionManager>) -> Self {
        completionExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        if status == .suspended ||
            status == .canceled ||
            status == .removed ||
            status == .succeeded ||
            status == .failed  {
            operationQueue.async {
                self.completionExecuter?.execute(self)
            }
        }
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
    }
    
    private func executeControl() {
        controlExecuter?.execute(self)
        controlExecuter = nil
    }
}


// MARK: - call back
extension SessionManager {
    internal func didBecomeInvalidation(withError error: Error?) {
        createSession { [weak self] in
            guard let self = self else { return }
            self.runningTasks.forEach { $0.prepareForDownload() }
            self.runningTasks.removeAll()
            self.waitingTasks.forEach { $0.prepareForDownload() }
            self.waitingTasks.removeAll()
        }
    }
    
    internal func didFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.tr.executeOnMain {
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
    
}


