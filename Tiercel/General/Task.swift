//
//  Task.swift
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

import Foundation

extension Task {
    public enum TRValidation: Int {
        case unkown
        case correct
        case incorrect
    }
}

public class Task: NSObject, NSCoding {

    internal weak var manager: SessionManager?

    internal var cache: Cache

    internal var session: URLSession?
    
    internal var headers: [String: String]?

    internal var verificationCode: String?
    
    internal var verificationType: FileVerificationType = .md5
    
    internal var progressExecuter: Executer<Task>?
    
    internal var successExecuter: Executer<Task>?
    
    internal var failureExecuter: Executer<Task>?
    
    internal var controlExecuter: Executer<Task>?
    
    internal var operationQueue: DispatchQueue

    internal let dataQueue = DispatchQueue(label: "com.Tiercel.Task.dataQueue")

    internal var request: URLRequest?
    
    private var _isRemoveCompletely = false
    internal var isRemoveCompletely: Bool {
        get {
            return dataQueue.sync {
                _isRemoveCompletely
            }
        }
        set {
            dataQueue.sync {
                _isRemoveCompletely = newValue
            }
        }
    }

    private var _status: Status = .waiting
    public var status: Status {
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
    
    private var _validation: TRValidation = .unkown
    public var validation: TRValidation {
        get {
            return dataQueue.sync {
                _validation
            }
        }
        set {
            dataQueue.sync {
                _validation = newValue
            }
        }
    }

    internal let url: URL
    
    public let URLString: String
    
    private var _currentURLString: String
    internal var currentURLString: String {
        get {
            return dataQueue.sync {
                _currentURLString
            }
        }
        set {
            dataQueue.sync {
                _currentURLString = newValue
            }
        }
    }
    

    public let progress: Progress = Progress()

    private var _startDate: Double = 0
    public internal(set) var startDate: Double {
        get {
            return dataQueue.sync {
                _startDate
            }
        }
        set {
            dataQueue.sync {
                _startDate = newValue
            }
        }
    }

    private var _endDate: Double = 0
    public internal(set) var endDate: Double {
        get {
            return dataQueue.sync {
                _endDate
            }
        }
        set {
            return dataQueue.sync {
                _endDate = newValue
            }
        }
    }


    private var _speed: Int64 = 0
    public internal(set) var speed: Int64 {
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

    /// 默认为url的md5加上文件扩展名
    private var _fileName: String
    public internal(set) var fileName: String {
        get {
            return dataQueue.sync {
                _fileName
            }
        }
        set {
            dataQueue.sync {
                _fileName = newValue
            }
        }
    }

    private var _timeRemaining: Int64 = 0
    public internal(set) var timeRemaining: Int64 {
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

    public internal(set) var error: Error?


    internal init(_ url: URL,
                  headers: [String: String]? = nil,
                  cache: Cache,
                  operationQueue:DispatchQueue) {
        self.cache = cache
        self.url = url
        self.URLString = url.absoluteString
        self.operationQueue = operationQueue
        _currentURLString = url.absoluteString
        _fileName = url.tr.fileName
        super.init()
        self.headers = headers
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(URLString, forKey: "URLString")
        aCoder.encode(currentURLString, forKey: "currentURLString")
        aCoder.encode(fileName, forKey: "fileName")
        aCoder.encode(headers, forKey: "headers")
        aCoder.encode(startDate, forKey: "startDate")
        aCoder.encode(endDate, forKey: "endDate")
        aCoder.encode(progress.totalUnitCount, forKey: "totalBytes")
        aCoder.encode(progress.completedUnitCount, forKey: "completedBytes")
        aCoder.encode(status.rawValue, forKey: "status")
        aCoder.encode(verificationCode, forKey: "verificationCode")
        aCoder.encode(verificationType.rawValue, forKey: "verificationType")
        aCoder.encode(validation.rawValue, forKey: "validation")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        cache = Cache("default")
        URLString = aDecoder.decodeObject(forKey: "URLString") as! String
        url = URL(string: URLString)!
        _currentURLString = aDecoder.decodeObject(forKey: "currentURLString") as! String
        _fileName = aDecoder.decodeObject(forKey: "fileName") as! String
        operationQueue = DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue")
        super.init()

        headers = aDecoder.decodeObject(forKey: "headers") as? [String: String]
        startDate = aDecoder.decodeDouble(forKey: "startDate")
        endDate = aDecoder.decodeDouble(forKey: "endDate")
        progress.totalUnitCount = aDecoder.decodeInt64(forKey: "totalBytes")
        progress.completedUnitCount = aDecoder.decodeInt64(forKey: "completedBytes")
        verificationCode = aDecoder.decodeObject(forKey: "verificationCode") as? String

        let statusString = aDecoder.decodeObject(forKey: "status") as! String
        status = Status(rawValue: statusString)!
        let verificationTypeInt = aDecoder.decodeInteger(forKey: "verificationType")
        verificationType = FileVerificationType(rawValue: verificationTypeInt)!

        let validationType = aDecoder.decodeInteger(forKey: "validation")
        validation = TRValidation(rawValue: validationType)!
    }



    internal func start() {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 0)
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        self.request = request
    }
    

    internal func suspend(onMainQueue: Bool = true, _ handler: Handler<Task>? = nil) {
        
        
    }
    
    internal func cancel(onMainQueue: Bool = true, _ handler: Handler<Task>? = nil) {
        
        
    }
    
    internal func remove(completely: Bool = false, onMainQueue: Bool = true, _ handler: Handler<Task>? = nil) {
        
    }
    
    internal func completed() {
        
    }
    
    internal func asDownloadTask() -> DownloadTask? {
        return self as? DownloadTask
    }
    
}

extension Task {
    @discardableResult
    public func progress(onMainQueue: Bool = true, _ handler: @escaping Handler<Task>) -> Self {
        return operationQueue.sync {
            progressExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            return self
        }

    }

    @discardableResult
    public func success(onMainQueue: Bool = true, _ handler: @escaping Handler<Task>) -> Self {
        return operationQueue.sync {
            successExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            if status == .succeeded {
                successExecuter?.execute(self)
            }
            return self
        }

    }

    @discardableResult
    public func failure(onMainQueue: Bool = true, _ handler: @escaping Handler<Task>) -> Self {
        return operationQueue.sync {
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
}

extension Array where Element == Task {
    @discardableResult
    public func progress(onMainQueue: Bool = true, _ handler: @escaping Handler<Task>) -> [Element] {
        self.forEach { $0.progress(onMainQueue: onMainQueue, handler) }
        return self
    }

    @discardableResult
    public func success(onMainQueue: Bool = true, _ handler: @escaping Handler<Task>) -> [Element] {
        self.forEach { $0.success(onMainQueue: onMainQueue, handler) }
        return self
    }

    @discardableResult
    public func failure(onMainQueue: Bool = true, _ handler: @escaping Handler<Task>) -> [Element] {
        self.forEach { $0.failure(onMainQueue: onMainQueue, handler) }
        return self
    }
}
