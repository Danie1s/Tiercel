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

    private let queue = DispatchQueue(label: "com.Daniels.Tiercel.Task.queue")

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

    public internal(set) var progress: Progress = Progress()


    private var internalStartDate: Double = 0
    @objc public internal(set) var startDate: Double {
        get {
            return queue.sync {
                internalStartDate
            }
        }
        set {
            return queue.sync {
                internalStartDate = newValue
            }
        }
    }

    private var internalEndDate: Double = 0
    @objc public internal(set) var endDate: Double {
        get {
            return queue.sync {
                internalEndDate
            }
        }
        set {
            return queue.sync {
                internalEndDate = newValue
            }
        }
    }


    private var internalSpeed: Int64 = 0
    public internal(set) var speed: Int64 {
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

    /// 默认为url最后一部分
    private var internalFileName: String
    @objc public internal(set) var fileName: String {
        get {
            return queue.sync {
                internalFileName
            }
        }
        set {
            return queue.sync {
                internalFileName = newValue
            }
        }
    }

    private var internalTimeRemaining: Int64 = 0
    public internal(set) var timeRemaining: Int64 {
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

    public let url: URL
    
    public var error: NSError?


    
    public init(_ url: URL, cache: TRCache, isCacheInfo: Bool = false, progressHandler: TRTaskHandler? = nil, successHandler: TRTaskHandler? = nil, failureHandler: TRTaskHandler? = nil) {
        self.url = url
        self.internalFileName = url.lastPathComponent
        self.progressHandler = progressHandler
        self.successHandler = successHandler
        self.failureHandler = failureHandler
        self.internalURLString = url.absoluteString
        self.cache = cache

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

    internal func remove() {


    }

    internal func completed() {


    }
    
}

// MARK: - closure
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
