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

    public let url: URL
    
    public let progress: Progress = Progress()
    
    internal var progressExecuter: Executer<TaskType>?
    
    internal var successExecuter: Executer<TaskType>?
    
    internal var failureExecuter: Executer<TaskType>?
    
    internal var controlExecuter: Executer<TaskType>?
    
    internal var validateExecuter: Executer<TaskType>?
    
    internal struct State {
        var session: URLSession?
        var headers: [String: String]?
        var verificationCode: String?
        var verificationType: FileVerificationType = .md5
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
    
    
    internal let protectedState: Protector<State>
    
    internal var session: URLSession? {
        get { protectedState.directValue.session }
        set { protectedState.write { $0.session = newValue } }
    }
    
    internal var headers: [String: String]? {
        get { protectedState.directValue.headers }
        set { protectedState.write { $0.headers = newValue } }
    }
    
    internal var verificationCode: String? {
        get { protectedState.directValue.verificationCode }
        set { protectedState.write { $0.verificationCode = newValue } }
    }
    
    internal var verificationType: FileVerificationType {
        get { protectedState.directValue.verificationType }
        set { protectedState.write { $0.verificationType = newValue } }
    }
    
    internal var isRemoveCompletely: Bool {
        get { protectedState.directValue.isRemoveCompletely }
        set { protectedState.write { $0.isRemoveCompletely = newValue } }
    }

    public internal(set) var status: Status {
        get { protectedState.directValue.status }
        set { protectedState.write { $0.status = newValue } }
    }
    
    public internal(set) var validation: Validation {
        get { protectedState.directValue.validation }
        set { protectedState.write { $0.validation = newValue } }
    }
    
    internal var currentURL: URL {
        get { protectedState.directValue.currentURL }
        set { protectedState.write { $0.currentURL = newValue } }
    }


    public internal(set) var startDate: Double {
        get { protectedState.directValue.startDate }
        set { protectedState.write { $0.startDate = newValue } }
    }

    public internal(set) var endDate: Double {
       get { protectedState.directValue.endDate }
       set { protectedState.write { $0.endDate = newValue } }
    }


    public internal(set) var speed: Int64 {
        get { protectedState.directValue.speed }
        set { protectedState.write { $0.speed = newValue } }
    }

    /// 默认为url的md5加上文件扩展名
    public internal(set) var fileName: String {
        get { protectedState.directValue.fileName }
        set { protectedState.write { $0.fileName = newValue } }
    }

    public internal(set) var timeRemaining: Int64 {
        get { protectedState.directValue.timeRemaining }
        set { protectedState.write { $0.timeRemaining = newValue } }
    }

    public internal(set) var error: Error?


    internal init(_ url: URL,
                  headers: [String: String]? = nil,
                  cache: Cache,
                  operationQueue:DispatchQueue) {
        self.cache = cache
        self.url = url
        self.operationQueue = operationQueue
        protectedState = Protector(State(currentURL: url, fileName: url.tr.fileName))
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
        let currentURL = try container.decode(URL.self, forKey: .currentURL)
        let fileName = try container.decode(String.self, forKey: .fileName)
        protectedState = Protector(State(currentURL: currentURL, fileName: fileName))
        cache = decoder.userInfo[.cache] as? Cache ?? Cache("default")
        operationQueue = decoder.userInfo[.operationQueue] as? DispatchQueue ?? DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue")
        super.init()

        progress.totalUnitCount = try container.decode(Int64.self, forKey: .totalBytes)
        progress.completedUnitCount = try container.decode(Int64.self, forKey: .completedBytes)
        
        let statusString = try container.decode(String.self, forKey: .status)
        let verificationTypeInt = try container.decode(Int.self, forKey: .verificationType)
        let validationType = try container.decode(Int.self, forKey: .validation)
        
        try protectedState.write {
            $0.headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
            $0.startDate = try container.decode(Double.self, forKey: .startDate)
            $0.endDate = try container.decode(Double.self, forKey: .endDate)
            $0.verificationCode = try container.decodeIfPresent(String.self, forKey: .verificationCode)
            $0.status = Status(rawValue: statusString)!
            $0.verificationType = FileVerificationType(rawValue: verificationTypeInt)!
            $0.validation = Validation(rawValue: validationType)!
        }

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


