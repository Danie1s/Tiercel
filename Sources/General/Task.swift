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

public class Task<TaskType>: NSObject, Codable {
    
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
    
    internal var progressExecuter: Executer<TaskType>?
    
    internal var successExecuter: Executer<TaskType>?
    
    internal var failureExecuter: Executer<TaskType>?
    
    internal var controlExecuter: Executer<TaskType>?

    internal var validateExecuter: Executer<TaskType>?

    internal let dataQueue = DispatchQueue(label: "com.Tiercel.Task.dataQueue")
    
    struct MutableState {
        var isRemoveCompletely = false
        var status: Status = .waiting
        var validation: Validation = .unkown
        var currentURL: URL
        var startDate: Double = 0
        var endDate: Double = 0
        var speed: Int64 = 0
        var fileName: String
        var timeRemaining: Int64 = 0
    }
    
    
    internal let protectedMutableState: Protector<MutableState>

    public var status: Status {
        protectedMutableState.directValue.status
    }
    
    public var validation: Validation {
        protectedMutableState.directValue.validation
    }

    public let url: URL
    

    public let progress: Progress = Progress()

    public var startDate: Double {
        protectedMutableState.directValue.startDate
    }

    public var endDate: Double {
       protectedMutableState.directValue.endDate
    }


    public var speed: Int64 {
        protectedMutableState.directValue.speed
    }

    /// 默认为url的md5加上文件扩展名
    public var fileName: String {
        protectedMutableState.directValue.fileName
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
        protectedMutableState = Protector(MutableState(currentURL: url, fileName: url.tr.fileName))
        super.init()
        self.headers = headers
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(protectedMutableState.directValue.currentURL, forKey: .currentURL)
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
        let currentURL = try container.decode(URL.self, forKey: .currentURL)
        let fileName = try container.decode(String.self, forKey: .fileName)
        protectedMutableState = Protector(MutableState(currentURL: currentURL, fileName: fileName))
        cache = decoder.userInfo[.cache] as? Cache ?? Cache("default")
        operationQueue = decoder.userInfo[.operationQueue] as? DispatchQueue ?? DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue")
        super.init()

        headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
        try protectedMutableState.write { $0.startDate = try container.decode(Double.self, forKey: .startDate) }
        try protectedMutableState.write { $0.endDate = try container.decode(Double.self, forKey: .endDate) }
        progress.totalUnitCount = try container.decode(Int64.self, forKey: .totalBytes)
        progress.completedUnitCount = try container.decode(Int64.self, forKey: .completedBytes)
        verificationCode = try container.decodeIfPresent(String.self, forKey: .verificationCode)
        
        let statusString = try container.decode(String.self, forKey: .status)
        protectedMutableState.write { $0.status = Status(rawValue: statusString)! }

        let verificationTypeInt = try container.decode(Int.self, forKey: .verificationType)
        verificationType = FileVerificationType(rawValue: verificationTypeInt)!
        
        let validationType = try container.decode(Int.self, forKey: .validation)
        protectedMutableState.write { $0.validation = Validation(rawValue: validationType)! }

    }
    

    internal func execute(_ Executer: Executer<TaskType>?) {
        
    }
    
}


extension Task {
    @discardableResult
    public func progress(onMainQueue: Bool = true, _ handler: @escaping Handler<TaskType>) -> Self {
        return operationQueue.sync {
            progressExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            return self
        }

    }

    @discardableResult
    public func success(onMainQueue: Bool = true, _ handler: @escaping Handler<TaskType>) -> Self {
        operationQueue.sync {
            successExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        }
        operationQueue.async {
            if self.status == .succeeded {
                self.execute(self.successExecuter)
            }
        }
        return self

    }

    @discardableResult
    public func failure(onMainQueue: Bool = true, _ handler: @escaping Handler<TaskType>) -> Self {
        operationQueue.sync {
            failureExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        }
        operationQueue.async {
            if self.status == .suspended ||
                self.status == .canceled ||
                self.status == .removed ||
                self.status == .failed  {
                self.execute(self.failureExecuter)
            }
        }
        return self
    }
}


