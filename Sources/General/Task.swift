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

public protocol TaskDelegate: AnyObject {
        
    func task<TaskType>(_ task: Task<TaskType>, didChangeStatusTo newValue: Status)
    
    func taskDidStart<TaskType>(_ task: Task<TaskType>)

    func taskDidCancelOrRemove<TaskType>(_ task: Task<TaskType>)
    
    func task<TaskType>(_ task: Task<TaskType>, didSucceed fromRunning: Bool)
    
    func task<TaskType>(_ task: Task<TaskType>, didDetermineStatus fromRunning: Bool)
    
    func taskDidUpdateCurrentURL<TaskType>(_ task: Task<TaskType>)
    
    func taskDidUpdateProgress<TaskType>(_ task: Task<TaskType>)
    
    func taskDidCompleteFromRunning<TaskType>(_ task: Task<TaskType>)
}


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
        case error
    }
    
    enum CompletionType {
        case local
        case network(task: URLSessionTask, error: Error?)
    }
    
    enum InterruptType {
        case manual(_ fromRunningTask: Bool)
        case error(_ error: Error)
        case statusCode(_ statusCode: Int)
    }

    weak var delegate: TaskDelegate?

    let cache: Cache

    let operationQueue: DispatchQueue

    public let url: URL
    
    public let progress: Progress = Progress()

    struct MutableState {
        var headers: [String: String]?
        var verificationCode: String?
        var verificationType: FileChecksumHelper.VerificationType = .md5
        var isRemoveCompletely: Bool = false
        var status: Status = .waiting
        var validation: Validation = .unkown
        var currentURL: URL
        var startDate: Double = 0
        var endDate: Double = 0
        var speed: Int64 = 0
        var fileName: String
        var timeRemaining: Int64 = 0
        var error: Error?

        var progressExecuter: Executer<TaskType>?
        var successExecuter: Executer<TaskType>?
        var failureExecuter: Executer<TaskType>?
        var controlExecuter: Executer<TaskType>?
        var completionExecuter: Executer<TaskType>?
        var validateExecuter: Executer<TaskType>?
    }
    
    @Protected
    var mutableState: MutableState

    public var status: Status {
        mutableState.status
    }
    
    var currentURL: URL {
        mutableState.currentURL
    }
    
    public var validation: Validation {
        mutableState.validation
    }
    
    public var startDate: Double {
        mutableState.startDate
    }
    
    public var startDateString: String {
        startDate.tr.convertTimeToDateString()
    }

    public var endDate: Double {
        mutableState.endDate
    }
    
    public var endDateString: String {
        endDate.tr.convertTimeToDateString()
    }


    public var speed: Int64 {
        mutableState.speed
    }
    
    public var speedString: String {
        speed.tr.convertSpeedToString()
    }

    /// 默认为url的md5加上文件扩展名
    public var fileName: String {
        mutableState.fileName
    }

    public  var timeRemaining: Int64 {
        mutableState.timeRemaining
    }
    
    public var timeRemainingString: String {
        timeRemaining.tr.convertTimeToString()
    }

    public var error: Error? {
        mutableState.error
    }

    init(_ url: URL,
                  headers: [String: String]? = nil,
                  cache: Cache,
                  operationQueue:DispatchQueue) {
        self.cache = cache
        self.url = url
        self.operationQueue = operationQueue
        mutableState = MutableState(headers: headers, currentURL: url, fileName: url.tr.fileName)
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(mutableState.currentURL, forKey: .currentURL)
        try container.encode(fileName, forKey: .fileName)
        try container.encodeIfPresent(mutableState.headers, forKey: .headers)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(progress.totalUnitCount, forKey: .totalBytes)
        try container.encode(progress.completedUnitCount, forKey: .completedBytes)
        try container.encode(status.rawValue, forKey: .status)
        try container.encodeIfPresent(mutableState.verificationCode, forKey: .verificationCode)
        try container.encode(mutableState.verificationType.rawValue, forKey: .verificationType)
        try container.encode(validation.rawValue, forKey: .validation)
        if let error = error {
            let errorData: Data
            if #available(iOS 11.0, *) {
                errorData = try NSKeyedArchiver.archivedData(withRootObject: (error as NSError), requiringSecureCoding: true)
            } else {
                errorData = NSKeyedArchiver.archivedData(withRootObject: (error as NSError))
            }
            try container.encode(errorData, forKey: .error)
        }
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(URL.self, forKey: .url)
        let currentURL = try container.decode(URL.self, forKey: .currentURL)
        let fileName = try container.decode(String.self, forKey: .fileName)
        mutableState = MutableState(currentURL: currentURL, fileName: fileName)
        cache = decoder.userInfo[.cache] as! Cache
        operationQueue = decoder.userInfo[.operationQueue] as! DispatchQueue
        super.init()

        progress.totalUnitCount = try container.decode(Int64.self, forKey: .totalBytes)
        progress.completedUnitCount = try container.decode(Int64.self, forKey: .completedBytes)
        
        let statusString = try container.decode(String.self, forKey: .status)
        let verificationTypeInt = try container.decode(Int.self, forKey: .verificationType)
        let validationType = try container.decode(Int.self, forKey: .validation)
        
        try $mutableState.write {
            $0.headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
            $0.startDate = try container.decode(Double.self, forKey: .startDate)
            $0.endDate = try container.decode(Double.self, forKey: .endDate)
            $0.verificationCode = try container.decodeIfPresent(String.self, forKey: .verificationCode)
            let status = Status(rawValue: statusString)!
            $0.status = status == .waiting ? .suspended : status
            $0.verificationType = FileChecksumHelper.VerificationType(rawValue: verificationTypeInt)!
            $0.validation = Validation(rawValue: validationType)!
            if let errorData = try container.decodeIfPresent(Data.self, forKey: .error) {
                if #available(iOS 11.0, *) {
                    $0.error = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSError.self, from: errorData)
                } else {
                    $0.error = NSKeyedUnarchiver.unarchiveObject(with: errorData) as? NSError
                }
            }
        }
    }

    func execute(_ Executer: Executer<TaskType>?) {
        fatalError("Subclasses must override.")
    }

}


extension Task {
    @discardableResult
    public func progress(onMainQueue: Bool = true, handler: @escaping Handler<TaskType>) -> Self {
        mutableState.progressExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        return self
    }

    @discardableResult
    public func success(onMainQueue: Bool = true, handler: @escaping Handler<TaskType>) -> Self {
        mutableState.successExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        return self

    }

    @discardableResult
    public func failure(onMainQueue: Bool = true, handler: @escaping Handler<TaskType>) -> Self {
        mutableState.failureExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        return self
    }
    
    @discardableResult
    public func completion(onMainQueue: Bool = true, handler: @escaping Handler<TaskType>) -> Self {
        mutableState.completionExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        return self
    }
    
}


