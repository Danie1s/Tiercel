//
//  BridgeSessionManager.swift
//  Pods-SwiftDownloader_Example
//
//  Created by zhuangtao on 2019/11/3.
//

import Foundation

@objc
public class BridgeSessionManager : NSObject {
    
//    @objc
    public var sessionManager: SessionManager?
    
    @objc
    public var configuration: SessionConfiguration?
    
    @objc
    public var identifier = String("")
    
    @objc
    public static var logLevel: BridgeLogLevel = .detailed

    @objc
    public static var isControlNetworkActivityIndicator: Bool = true

//    public var operationQueue: DispatchQueue?

//    @objc
//    public var cache: Cache = Cache.init("")

//    public var identifier: String?

    @objc
    public var completionHandler: (() -> Void)?

    @objc
    public var status: BridgeStatus = .waiting

//    public private(set) var tasks: [DownloadTask]

    @objc
    public var speed: Int64 = 0

    @objc
    public var timeRemaining: Int64 = 0

    @objc(initWithIdentifier:configuration:operationQueue:)
    public convenience init(_ identifier: String,
                            configuration: SessionConfiguration,
                            operationQueue: DispatchQueue = DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue")) {
    
        self.init()
        self.identifier = identifier
        self.configuration = configuration
        self.sessionManager = SessionManager.init(identifier, configuration: configuration, operationQueue: operationQueue);
    }
    
    public override init() {
        super.init()
    }
    
    @objc
    public var completedTasks: [BridgeTask] {
        let tasks = sessionManager!.tasks.filter { $0.status == .succeeded }
        
        let bridgetasks = tasks.map { (task) -> BridgeTask in
            task.conversion()
        }
        return bridgetasks
    }
    
    @objc
    public var tasks:[BridgeTask] {
            let tasks:[DownloadTask] = sessionManager!.tasks;
            let bridgetasks = tasks.map { (task) -> BridgeTask in
                task.conversion()
            }
            return bridgetasks
    }
    
    @objc
    public var progress: Progress {
        return sessionManager!.progress
    }
    
    deinit {
        
    }
    
}

// MARK: - closure
extension BridgeSessionManager {
    
    @objc(progress:handler:)
    public func progress(onMainQueue: Bool = true, _ handler: @escaping Handler<SessionManager>) -> Self {
        sessionManager?.progress(onMainQueue: onMainQueue, { (manager) in
            handler(manager)
        })
        return self
    }
    
    @objc(success:handler:)
    public func success(onMainQueue: Bool = true, _ handler: @escaping Handler<SessionManager>) -> Self {
        sessionManager?.success(onMainQueue: onMainQueue, { (manager) in
            handler(manager)
        })
        return self
    }
    
    @objc(failure:handler:)
    public func failure(onMainQueue: Bool = true, _ handler: @escaping Handler<SessionManager>) -> Self {
        sessionManager?.failure(onMainQueue: onMainQueue, { (manager) in
            handler(manager)
        })
        return self
    }
}

// MARK: - download

extension BridgeSessionManager {
    
    @objc(download:headers:fileName:)
    public func download(_ url: String,
                         headers: [String: String]? = nil,
                         fileName: String? = nil) -> BridgeTask? {
        let downloadTask =
        self.sessionManager?.download(url, headers: headers, fileName: fileName)
        let bridgeTask = downloadTask?.conversion()
        return bridgeTask;
    }
    
    
    @objc(multiDownload:headers:fileNames:)
    public func multiDownload(_ urls: [String],
                              headers: [[String: String]]? = nil,
                              fileNames: [String]? = nil) -> [BridgeTask] {
        let tasks = self.sessionManager!.multiDownload(urls, headers: headers, fileNames: fileNames);
        let bridgetasks = tasks.map({ (task) -> BridgeTask in
            task.conversion()
        })
        return bridgetasks
    }
}

// MARK: - single task control
extension BridgeSessionManager {
    
    @objc(fetchTask:)
    public func fetchTask(_ url: String) -> BridgeTask? {
        return self.sessionManager!.fetchTask(url)?.conversion()
    }
    
    @objc(start:)
    public func start(_ url: String) {
        sessionManager?.start(url)
    }
    
    @objc(suspend:)
    public func suspend(_ url: String) {
        sessionManager?.suspend(url)
    }
    
    @objc(cancel:)
    public func cancel(_ url: String) {
        sessionManager?.cancel(url)
    }
    
    @objc(remove:completely:onMainQueue:handler:)
    public func remove(_ url: String, completely: Bool = false, onMainQueue: Bool = true, _ handler: Handler<BridgeTask>? = nil) {
        sessionManager?.remove(url, completely: completely, onMainQueue: onMainQueue, { (task) in
            guard let taskHandler = handler else { return }
            taskHandler(task.conversion())
        })
    }
    
    @objc(clearDisk)
    public func clearDisk(){
        sessionManager?.cache.clearDiskCache()
    }
}

// MARK: - total task control
extension BridgeSessionManager {
    
    @objc(totalStart)
    public func totalStart() {
        self.sessionManager?.totalStart()
    }
    
    @objc(totalSuspend:handler:)
    public func totalSuspend(onMainQueue: Bool = true, _ handler: Handler<SessionManager>? = nil) {
        self.sessionManager?.totalSuspend(onMainQueue: onMainQueue, handler)
    }
    
    @objc(totalCancel:handler:)
    public func totalCancel(onMainQueue: Bool = true, _ handler: Handler<SessionManager>? = nil) {
        self.sessionManager?.totalCancel(onMainQueue: onMainQueue, handler)
    }
    
    @objc(totalRemove:onMainQueue:handler:)
    public func totalRemove(completely: Bool = false, onMainQueue: Bool = true, _ handler: Handler<SessionManager>? = nil) {
        self.sessionManager?.totalRemove(completely: completely, onMainQueue: onMainQueue, handler)
    }
}
