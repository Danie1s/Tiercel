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
    public enum Validation: Int {
        case unkown
        case correct
        case incorrect
    }
}

public class Task<T>: NSObject, NSCoding, Codable {
    
    private enum CodingKeys: CodingKey {
        case url
        case currentURL
        case fileName
        case headers
        case startDate
        case endDate
        case totalBytes
        case completedBytes
        case verificationCode
        case status
        case verificationType
        case validation
    }

    internal weak var manager: SessionManager?

    internal var cache: Cache

    internal var operationQueue: DispatchQueue

    internal var session: URLSession?
    
    internal var headers: [String: String]?

    internal var verificationCode: String?
    
    internal var verificationType: FileVerificationType = .md5
    
    internal var progressExecuter: Executer<T>?
    
    internal var successExecuter: Executer<T>?
    
    internal var failureExecuter: Executer<T>?
    
    internal var controlExecuter: Executer<T>?

    internal var validateExecuter: Executer<T>?

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
    
    private var _validation: Validation = .unkown
    public var validation: Validation {
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

    public let url: URL
    
    private var _currentURL: URL
    internal var currentURL: URL {
        get {
            return dataQueue.sync {
                _currentURL
            }
        }
        set {
            dataQueue.sync {
                _currentURL = newValue
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
        self.operationQueue = operationQueue
        _currentURL = url
        _fileName = url.tr.fileName
        super.init()
        self.headers = headers
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(currentURL, forKey: .currentURL)
        try container.encode(fileName, forKey: .fileName)
        try container.encodeIfPresent(headers, forKey: .headers)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(progress.totalUnitCount, forKey: .totalBytes)
        try container.encode(progress.completedUnitCount, forKey: .completedBytes)
        try container.encode(status.rawValue, forKey: .status)
        try container.encodeIfPresent(verificationCode, forKey: .verificationCode)
        try container.encode(verificationType.rawValue, forKey: .verificationType)
        try container.encode(validation.rawValue, forKey: .validation)
        
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(URL.self, forKey: .url)
        _currentURL = try container.decode(URL.self, forKey: .currentURL)
        _fileName = try container.decode(String.self, forKey: .fileName)
        cache = decoder.userInfo[.cache] as? Cache ?? Cache("default")
        operationQueue = decoder.userInfo[.operationQueue] as? DispatchQueue ?? DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue")
        super.init()

        headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
        startDate = try container.decode(Double.self, forKey: .startDate)
        endDate = try container.decode(Double.self, forKey: .endDate)
        progress.totalUnitCount = try container.decode(Int64.self, forKey: .totalBytes)
        progress.completedUnitCount = try container.decode(Int64.self, forKey: .completedBytes)
        verificationCode = try container.decodeIfPresent(String.self, forKey: .verificationCode)
        
        let statusString = try container.decode(String.self, forKey: .status)
        status = Status(rawValue: statusString)!
        let verificationTypeInt = try container.decode(Int.self, forKey: .verificationType)
        verificationType = FileVerificationType(rawValue: verificationTypeInt)!
        
        let validationType = try container.decode(Int.self, forKey: .validation)
        validation = Validation(rawValue: validationType)!

    }
    
    @available(*, deprecated, message: "Use encode(to:) instead.")
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(url.absoluteString, forKey: "url")
        aCoder.encode(currentURL.absoluteString, forKey: "currentURL")
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
    
    @available(*, deprecated, message: "Use init(from:) instead.")
    public required init?(coder aDecoder: NSCoder) {
        cache = Cache("default")
        let URLString = aDecoder.decodeObject(forKey: "URLString") as! String
        url = try! URLString.asURL()
        let currentURLSting = aDecoder.decodeObject(forKey: "currentURLString") as! String
        _currentURL = try! currentURLSting.asURL()
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
        validation = Validation(rawValue: validationType)!
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
    
    internal func executeHandler(_ Executer: Executer<T>?) {
        
    }
    
}


extension Task {
    @discardableResult
    public func progress(onMainQueue: Bool = true, _ handler: @escaping Handler<T>) -> Self {
        return operationQueue.sync {
            progressExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            return self
        }

    }

    @discardableResult
    public func success(onMainQueue: Bool = true, _ handler: @escaping Handler<T>) -> Self {
        operationQueue.sync {
            successExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        }
        operationQueue.async {
            if self.status == .succeeded {
                self.executeHandler(self.successExecuter)
            }
        }
        return self

    }

    @discardableResult
    public func failure(onMainQueue: Bool = true, _ handler: @escaping Handler<T>) -> Self {
        operationQueue.sync {
            failureExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        }
        operationQueue.async {
            if self.status == .suspended ||
                self.status == .canceled ||
                self.status == .removed ||
                self.status == .failed  {
                self.executeHandler(self.failureExecuter)
            }
        }
        return self
    }
}


