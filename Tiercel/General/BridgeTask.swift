//
//  BridgeTask.swift
//  Pods-SwiftDownloader_Example
//
//  Created by zhuangtao on 2019/11/3.
//

import UIKit

public typealias TaskHandler = (BridgeTask) -> ()

@objc
public class BridgeTask: NSObject {
    
    @objc
    public var filePath: String?
    
    @objc
    public var fileName: String?
    
    @objc
    public var url: URL?
    
    @objc
    public var headers: [String: String]?
    
    public var cache: Cache?
    
    @objc
    public var dispatchQueue: DispatchQueue?
    
    @objc
    public var progress: Progress = Progress()
    
    @objc
    public var status: BridgeStatus = .waiting
    
    @objc
    public var validation: Validation = .unkown
    
    internal weak var task: DownloadTask?

//    public var validation: Validation

//    public let url: URL
//
//    public let progress: Progress

    @objc
    public internal(set) var startDate: Double = 0

    @objc
    public internal(set) var endDate: Double = 0

    @objc
    public internal(set) var speed: Int64 = 0

//    public internal(set) var fileName: String

    @objc
    public internal(set) var timeRemaining: Int64 = 0

    @objc
    public internal(set) var error: Error? = nil
    
    public override init() {
        super.init()
    }
    
    @objc(progress:handler:)
    public func progress(onMainQueue: Bool = true, _ handler: @escaping TaskHandler) -> Self {
        self.task?.progress({ (task) in
            handler(task.conversion())
        })
        return self
    }
    @objc(success:handler:)
    public func success(onMainQueue: Bool = true, _ handler: @escaping TaskHandler) -> Self {
        self.task?.success({ (task) in
            handler(task.conversion())
        })
        return self

    }
    @objc(failure:handler:)
    public func failure(onMainQueue: Bool = true, _ handler: @escaping TaskHandler) -> Self {
        self.task?.failure({ (task) in
            handler(task.conversion())
        })
        return self
    }
    
    @objc(validateFile:type:onMainQueue:handler:)
    public func validateFile(code: String,
                             type: FileVerificationType,
                             onMainQueue: Bool = true,
                             _ handler: @escaping TaskHandler) -> Self {

        self.task?.validateFile(code: code, type: type, onMainQueue: onMainQueue, { (task) in
            handler(task.conversion())
        })
        return self
    }
    
    deinit {
        
    }

}



// MARK: - closure
extension DownloadTask {
    

}
