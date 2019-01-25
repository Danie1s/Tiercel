//
//  TRTask.swift
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

extension TRTask {
    public enum TRValidation: Int {
        case unkown
        case correct
        case incorrect
    }
}


public class TRTask: NSObject, NSCoding {

    internal weak var manager: TRManager?
    internal var cache: TRCache
    internal var session: URLSession?
    
    internal var headers: [String: String]?

    internal var verificationCode: String?
    internal var verificationType: TRVerificationType = .md5
    
    internal var progressHandler: TRTaskHandler?
    internal var successHandler: TRTaskHandler?
    internal var failureHandler: TRTaskHandler?
    internal var controlHandler: TRTaskHandler?
    internal var validateHandler: TRTaskHandler?


    private let queue = DispatchQueue(label: "com.Daniels.Tiercel.Task.queue")

    internal var request: URLRequest?

    private var _status: TRStatus = .waiting
    public var status: TRStatus {
        get {
            return queue.sync {
                _status
            }
        }
        set {
            return queue.sync {
                _status = newValue
            }
        }
    }
    
    private var _validation: TRValidation = .unkown
    public var validation: TRValidation {
        get {
            return queue.sync {
                _validation
            }
        }
        set {
            return queue.sync {
                _validation = newValue
            }
        }
    }

    internal let url: URL
    
    public let URLString: String
    
    private var _currentURLString: String
    internal var currentURLString: String {
        get {
            return queue.sync {
                _currentURLString
            }
        }
        set {
            return queue.sync {
                _currentURLString = newValue
            }
        }
    }
    

    public let progress: Progress = Progress()

    private var _startDate: Double = 0
    public internal(set) var startDate: Double {
        get {
            return queue.sync {
                _startDate
            }
        }
        set {
            return queue.sync {
                _startDate = newValue
            }
        }
    }

    private var _endDate: Double = 0
    public internal(set) var endDate: Double {
        get {
            return queue.sync {
                _endDate
            }
        }
        set {
            return queue.sync {
                _endDate = newValue
            }
        }
    }


    private var _speed: Int64 = 0
    public internal(set) var speed: Int64 {
        get {
            return queue.sync {
                _speed
            }
        }
        set {
            return queue.sync {
                _speed = newValue
            }
        }
    }

    /// 默认为url的md5加上文件扩展名
    private var _fileName: String
    public internal(set) var fileName: String {
        get {
            return queue.sync {
                _fileName
            }
        }
        set {
            return queue.sync {
                _fileName = newValue
            }
        }
    }

    private var _timeRemaining: Int64 = 0
    public internal(set) var timeRemaining: Int64 {
        get {
            return queue.sync {
                _timeRemaining
            }
        }
        set {
            return queue.sync {
                _timeRemaining = newValue
            }
        }
    }

    public internal(set) var error: Error?



    public init(_ url: URL,
                headers: [String: String]? = nil,
                cache: TRCache) {
        self.cache = cache
        self.url = url
        self.URLString = url.absoluteString
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
        cache = TRCache.default
        URLString = aDecoder.decodeObject(forKey: "URLString") as! String
        url = URL(string: URLString)!
        _currentURLString = aDecoder.decodeObject(forKey: "currentURLString") as! String
        _fileName = aDecoder.decodeObject(forKey: "fileName") as! String
        super.init()
        
        headers = aDecoder.decodeObject(forKey: "headers") as? [String: String]
        startDate = aDecoder.decodeDouble(forKey: "startDate")
        endDate = aDecoder.decodeDouble(forKey: "endDate")
        progress.totalUnitCount = aDecoder.decodeInt64(forKey: "totalBytes")
        progress.completedUnitCount = aDecoder.decodeInt64(forKey: "completedBytes")
        verificationCode = aDecoder.decodeObject(forKey: "verificationCode") as? String
        
        let statusString = aDecoder.decodeObject(forKey: "status") as! String
        status = TRStatus(rawValue: statusString)!
        let verificationTypeInt = aDecoder.decodeInteger(forKey: "verificationType")
        verificationType = TRVerificationType(rawValue: verificationTypeInt)!
        
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
    

    
    internal func suspend(_ handler: TRTaskHandler? = nil) {
        
        
    }
    
    internal func cancel(_ handler: TRTaskHandler? = nil) {
        
        
    }

    internal func remove(_ handler: TRTaskHandler? = nil) {


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

extension Array where Element == TRTask {
    @discardableResult
    public func progress(_ handler: @escaping TRTaskHandler) -> [TRTask] {
        self.forEach { $0.progress(handler) }
        return self
    }

    @discardableResult
    public func success(_ handler: @escaping TRTaskHandler) -> [TRTask] {
        self.forEach { $0.success(handler) }
        return self
    }

    @discardableResult
    public func failure(_ handler: @escaping TRTaskHandler) -> [TRTask] {
        self.forEach { $0.failure(handler) }
        return self
    }
}


