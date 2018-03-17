//
//  TRTask.swift
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

import Foundation

public class TRTask: NSObject {
    
    internal weak var manager: TRManager?
    internal var cache: TRCache
    internal var session: URLSession?

    internal var progressHandler: TRTaskHandler?
    internal var successHandler: TRTaskHandler?
    internal var failureHandler: TRTaskHandler?

    private let queue = DispatchQueue(label: "com.Daniels.Falcon.Task.queue")

    internal var request: URLRequest?

    private var internalStatus: TRStatus = .waiting
    public var status: TRStatus {
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


    private var internalURLString: String
    @objc public var URLString: String {
        get {
            return queue.sync {
                internalURLString
            }
        }
        set {
            return queue.sync {
                internalURLString = newValue
            }
        }
    }

    public var progress: Progress = Progress()

    @objc public var startDate: TimeInterval = 0
    @objc public var endDate: TimeInterval = Date().timeIntervalSince1970
    @objc public var speed: Int64 = 0

    /// 默认为url最后一部分
    @objc public internal(set) var fileName: String

    public var timeRemaining: Int64 = 0

    public let url: URL
    
    public var error: NSError?


    
    public init(_ url: URL, cache: TRCache?, isCacheInfo: Bool = false, progressHandler: TRTaskHandler? = nil, successHandler: TRTaskHandler? = nil, failureHandler: TRTaskHandler? = nil) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.progressHandler = progressHandler
        self.successHandler = successHandler
        self.failureHandler = failureHandler
        self.internalURLString = url.absoluteString
        if let cache = cache {
            self.cache = cache
        } else {
            self.cache = TRCache.default
        }
        super.init()
    }

    
    open override func setValue(_ value: Any?, forUndefinedKey key: String) {
        if key == "status" {
            status = TRStatus(rawValue: value as! String)!
        }
    }


    internal func start() {
        let requestUrl = URL(string: URLString)!
        let request = URLRequest(url: requestUrl, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 0)
        self.request = request
    }
    

    
    internal func suspend() {
        
        
    }
    
    internal func cancel() {
        
        
    }

    internal func completed() {


    }
    
}

// MARK: - handler
extension TRTask {
    @discardableResult
    public func progress(_ handler: @escaping TRTaskHandler) -> Self {
        progressHandler = handler
        return self
    }

    @discardableResult
    public func success(_ handler: @escaping TRTaskHandler) -> Self {
        successHandler = handler
        return self
    }

    @discardableResult
    public func failure(_ handler: @escaping TRTaskHandler) -> Self {
        failureHandler = handler
        return self
    }
}
