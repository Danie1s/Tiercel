//
//  DownloadTask.swift
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

import UIKit

public class DownloadTask: Task<DownloadTask> {
    
    private enum CodingKeys: CodingKey {
        case resumeData
        case response
    }

    private var acceptableStatusCodes: Range<Int> { return 200..<300 }
    
    private var _sessionTask: URLSessionDownloadTask? {
        willSet {
            _sessionTask?.removeObserver(self, forKeyPath: "currentRequest")
        }
        didSet {
            _sessionTask?.addObserver(self, forKeyPath: "currentRequest", options: [.new], context: nil)
        }
    }
    
    internal var sessionTask: URLSessionDownloadTask? {
        get { protectedDownloadState.read { _ in _sessionTask }}
        set { protectedDownloadState.write { _ in _sessionTask = newValue }}
    }
    

    public private(set) var response: HTTPURLResponse? {
        get { protectedDownloadState.wrappedValue.response }
        set { protectedDownloadState.write { $0.response = newValue } }
    }
    

    public var filePath: String {
        return cache.filePath(fileName: fileName)!
    }

    public var pathExtension: String? {
        let pathExtension = (filePath as NSString).pathExtension
        return pathExtension.isEmpty ? nil : pathExtension
    }


    private struct DownloadState {
        var resumeData: Data? {
            didSet {
                guard let resumeData = resumeData else { return }
                tmpFileName = ResumeDataHelper.getTmpFileName(resumeData)
            }
        }
        var response: HTTPURLResponse?
        var tmpFileName: String?
        var shouldValidateFile: Bool = false
    }
    
    private let protectedDownloadState: Protected<DownloadState> = Protected(DownloadState())
    
    
    private var resumeData: Data? {
        get { protectedDownloadState.wrappedValue.resumeData }
        set { protectedDownloadState.write { $0.resumeData = newValue } }
    }
    
    internal var tmpFileName: String? {
        protectedDownloadState.wrappedValue.tmpFileName
    }

    private var shouldValidateFile: Bool {
        get { protectedDownloadState.wrappedValue.shouldValidateFile }
        set { protectedDownloadState.write { $0.shouldValidateFile = newValue } }
    }


    internal init(_ url: URL,
                  headers: [String: String]? = nil,
                  fileName: String? = nil,
                  cache: Cache,
                  operationQueue: DispatchQueue) {
        super.init(url,
                   headers: headers,
                   cache: cache,
                   operationQueue: operationQueue)
        if let fileName = fileName, !fileName.isEmpty {
            self.fileName = fileName
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fixDelegateMethodError),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
        try container.encodeIfPresent(resumeData, forKey: .resumeData)
        if let response = response {
            let responseData: Data
            if #available(iOS 11.0, *) {
                responseData = try NSKeyedArchiver.archivedData(withRootObject: (response as HTTPURLResponse), requiringSecureCoding: true)
            } else {
                responseData = NSKeyedArchiver.archivedData(withRootObject: (response as HTTPURLResponse))
            }
            try container.encode(responseData, forKey: .response)
        }
    }
    
    internal required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        resumeData = try container.decodeIfPresent(Data.self, forKey: .resumeData)
        if let responseData = try container.decodeIfPresent(Data.self, forKey: .response) {
            if #available(iOS 11.0, *) {
                response = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HTTPURLResponse.self, from: responseData)
            } else {
                response = NSKeyedUnarchiver.unarchiveObject(with: responseData) as? HTTPURLResponse
            }
        }
    }
    
    
    deinit {
        sessionTask?.removeObserver(self, forKeyPath: "currentRequest")
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func fixDelegateMethodError() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sessionTask?.suspend()
            self.sessionTask?.resume()
        }
    }


    internal override func execute(_ executer: Executer<DownloadTask>?) {
        executer?.execute(self)
    }
    

}


// MARK: - control
extension DownloadTask {

    internal func download() {
        cache.createDirectory()
        guard let manager = manager else { return }
        switch status {
        case .waiting, .suspended, .failed:
            if cache.fileExists(fileName: fileName) {
                prepareForDownload(fileExists: true)
            } else {
                if manager.shouldRun {
                    prepareForDownload(fileExists: false)
                } else {
                    status = .waiting
                    progressExecuter?.execute(self)
                    executeControl()
                }
            }
        case .succeeded:
            executeControl()
            succeeded(fromRunning: false, immediately: false)
        case .running:
            status = .running
            executeControl()
        default: break
        }
    }
    
    private func prepareForDownload(fileExists: Bool) {
        status = .running
        protectedState.write {
            $0.speed = 0
            if $0.startDate == 0 {
                 $0.startDate = Date().timeIntervalSince1970
            }
        }
        error = nil
        response = nil
        start(fileExists: fileExists)
    }

    private func start(fileExists: Bool) {
        if fileExists {
            manager?.log(.downloadTask("file already exists", task: self))
            if let fileInfo = try? FileManager.default.attributesOfItem(atPath: cache.filePath(fileName: fileName)!),
                let length = fileInfo[.size] as? Int64 {
                progress.totalUnitCount = length
            }
            executeControl()
            operationQueue.async {
                self.didComplete(.local)
            }
        } else {
            if let resumeData = resumeData,
                cache.retrieveTmpFile(tmpFileName) {
                if #available(iOS 10.2, *) {
                    sessionTask = session?.downloadTask(withResumeData: resumeData)
                } else if #available(iOS 10.0, *) {
                    sessionTask = session?.correctedDownloadTask(withResumeData: resumeData)
                } else {
                    sessionTask = session?.downloadTask(withResumeData: resumeData)
                }
            } else {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 0)
                if let headers = headers {
                    request.allHTTPHeaderFields = headers
                }
                sessionTask = session?.downloadTask(with: request)
                progress.completedUnitCount = 0
                progress.totalUnitCount = 0
            }
            progress.setUserInfoObject(progress.completedUnitCount, forKey: .fileCompletedCountKey)
            sessionTask?.resume()
            manager?.maintainTasks(with: .appendRunningTasks(self))
            manager?.storeTasks()
            executeControl()
        }
    }


    internal func suspend(onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        guard status == .running || status == .waiting else { return }
        controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        if status == .running {
            status = .willSuspend
            sessionTask?.cancel(byProducingResumeData: { _ in })
        } else {
            status = .willSuspend
            operationQueue.async {
                self.didComplete(.local)
            }
        }
    }

    internal func cancel(onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        guard status != .succeeded else { return }
        controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        if status == .running {
            status = .willCancel
            sessionTask?.cancel()
        } else {
            status = .willCancel
            operationQueue.async {
                self.didComplete(.local)
            }
        }
    }

    

    internal func remove(completely: Bool = false, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        isRemoveCompletely = completely
        controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        if status == .running {
            status = .willRemove
            sessionTask?.cancel()
        } else {
            status = .willRemove
            operationQueue.async {
                self.didComplete(.local)
            }
        }
    }


    internal func update(_ newHeaders: [String: String]? = nil, newFileName: String? = nil) {
        headers = newHeaders
        if let newFileName = newFileName, !newFileName.isEmpty {
            cache.updateFileName(filePath, newFileName)
            fileName = newFileName
        }
    }

    private func validateFile() {
        guard let validateHandler = self.validateExecuter else { return }

        if !shouldValidateFile {
            validateHandler.execute(self)
            return
        }

        guard let verificationCode = verificationCode else { return }

        FileChecksumHelper.validateFile(filePath, code: verificationCode, type: verificationType) { [weak self] (result) in
            guard let self = self else { return }
            self.shouldValidateFile = false
            if case let .failure(error) = result {
                self.validation = .incorrect
                self.manager?.log(.error("file validation failed, url: \(self.url)", error: error))
            } else {
                self.validation = .correct
                self.manager?.log(.downloadTask("file validation successful", task: self))
            }
            self.manager?.storeTasks()
            validateHandler.execute(self)
        }
    }

}



// MARK: - status handle
extension DownloadTask {

    private func didCancelOrRemove() {
        // 把预操作的状态改成完成操作的状态
        if status == .willCancel {
            status = .canceled
        }
        if status == .willRemove {
            status = .removed
        }
        cache.remove(self, completely: isRemoveCompletely)
        
        manager?.didCancelOrRemove(self)
    }


    internal func succeeded(fromRunning: Bool, immediately: Bool) {
        if endDate == 0 {
            protectedState.write {
                $0.endDate = Date().timeIntervalSince1970
                $0.timeRemaining = 0
            }
        }
        status = .succeeded
        progress.completedUnitCount = progress.totalUnitCount
        progressExecuter?.execute(self)
        if immediately {
          executeCompletion(true)
        }
        validateFile()
        manager?.maintainTasks(with: .succeeded(self))
        manager?.determineStatus(fromRunningTask: fromRunning)
    }
    
    
    private func determineStatus(with interruptType: InterruptType) {
        var fromRunning = true
        switch interruptType {
        case let .error(error):
            self.error = error
            var tempStatus = status
            if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                self.resumeData = ResumeDataHelper.handleResumeData(resumeData)
                cache.storeTmpFile(tmpFileName)
            }
            if let _ = (error as NSError).userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int {
                tempStatus = .suspended
            }
            if let urlError = error as? URLError, urlError.code != URLError.cancelled {
                tempStatus = .failed
            }
            status = tempStatus
        case let .statusCode(statusCode):
            self.error = TiercelError.unacceptableStatusCode(code: statusCode)
            status = .failed
        case let .manual(fromRunningTask):
            fromRunning = fromRunningTask
        }
        
        switch status {
        case .willSuspend:
            status = .suspended
            progressExecuter?.execute(self)
            executeControl()
            executeCompletion(false)
        case .willCancel, .willRemove:
            didCancelOrRemove()
            executeControl()
            executeCompletion(false)
        case .suspended, .failed:
            progressExecuter?.execute(self)
            executeCompletion(false)
        default:
            status = .failed
            progressExecuter?.execute(self)
            executeCompletion(false)
        }
        manager?.determineStatus(fromRunningTask: fromRunning)
    }
}

// MARK: - closure
extension DownloadTask {
    @discardableResult
    public func validateFile(code: String,
                             type: FileChecksumHelper.VerificationType,
                             onMainQueue: Bool = true,
                             handler: @escaping Handler<DownloadTask>) -> Self {
         operationQueue.async {
            let (verificationCode, verificationType) = self.protectedState.read {
                                                            ($0.verificationCode, $0.verificationType)
                                                        }
            if verificationCode == code &&
                verificationType == type &&
                self.validation != .unkown {
                self.shouldValidateFile = false
            } else {
                self.shouldValidateFile = true
                self.protectedState.write {
                    $0.verificationCode = code
                    $0.verificationType = type
                }
                self.manager?.storeTasks()
            }
            self.validateExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            if self.status == .succeeded {
                self.validateFile()
            }
        }
        return self
    }
    
    private func executeCompletion(_ isSucceeded: Bool) {
        if let completionExecuter = completionExecuter {
            completionExecuter.execute(self)
        } else if isSucceeded {
            successExecuter?.execute(self)
        } else {
            failureExecuter?.execute(self)
        }
        NotificationCenter.default.postNotification(name: DownloadTask.didCompleteNotification, downloadTask: self)
    }
    
    private func executeControl() {
        controlExecuter?.execute(self)
        controlExecuter = nil
    }
}



// MARK: - KVO
extension DownloadTask {
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let change = change, let newRequest = change[NSKeyValueChangeKey.newKey] as? URLRequest, let url = newRequest.url {
            currentURL = url
            manager?.updateUrlMapper(with: self)
        }
    }
}

// MARK: - info
extension DownloadTask {

    internal func updateSpeedAndTimeRemaining() {

        let dataCount = progress.completedUnitCount
        let lastData: Int64 = progress.userInfo[.fileCompletedCountKey] as? Int64 ?? 0

        if dataCount > lastData {
            let speed = dataCount - lastData
            updateTimeRemaining(speed)
        }
        progress.setUserInfoObject(dataCount, forKey: .fileCompletedCountKey)

    }

    private func updateTimeRemaining(_ speed: Int64) {
        var timeRemaining: Double
        if speed != 0 {
            timeRemaining = (Double(progress.totalUnitCount) - Double(progress.completedUnitCount)) / Double(speed)
            if timeRemaining >= 0.8 && timeRemaining < 1 {
                timeRemaining += 1
            }
        } else {
            timeRemaining = 0
        }
        protectedState.write {
            $0.speed = speed
            $0.timeRemaining = Int64(timeRemaining)
        }
    }
}

// MARK: - callback
extension DownloadTask {
    internal func didWriteData(downloadTask: URLSessionDownloadTask, bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress.completedUnitCount = totalBytesWritten
        progress.totalUnitCount = totalBytesExpectedToWrite
        response = downloadTask.response as? HTTPURLResponse
        progressExecuter?.execute(self)
        manager?.updateProgress()
        NotificationCenter.default.postNotification(name: DownloadTask.runningNotification, downloadTask: self)
    }
    
    
    internal func didFinishDownloading(task: URLSessionDownloadTask, to location: URL) {
        guard let statusCode = (task.response as? HTTPURLResponse)?.statusCode,
            acceptableStatusCodes.contains(statusCode)
            else { return }
        cache.storeFile(at: location, to: URL(fileURLWithPath: filePath))
        cache.removeTmpFile(tmpFileName)

    }
    
    internal func didComplete(_ type: CompletionType) {
        switch type {
        case .local:
            
            switch status {
            case .willSuspend,.willCancel, .willRemove:
                determineStatus(with: .manual(false))
            case .running:
                succeeded(fromRunning: false, immediately: true)
            default:
                return
            }
            
        case let .network(task, error):
            manager?.maintainTasks(with: .removeRunningTasks(self))
            sessionTask = nil

            switch status {
            case .willCancel, .willRemove:
                determineStatus(with: .manual(true))
                return
            case .willSuspend, .running:
                progress.totalUnitCount = task.countOfBytesExpectedToReceive
                progress.completedUnitCount = task.countOfBytesReceived
                progress.setUserInfoObject(task.countOfBytesReceived, forKey: .fileCompletedCountKey)
                
                let statusCode = (task.response as? HTTPURLResponse)?.statusCode ?? -1
                let isAcceptable = acceptableStatusCodes.contains(statusCode)
                
                if error != nil {
                    response = task.response as? HTTPURLResponse
                    determineStatus(with: .error(error!))
                } else if !isAcceptable {
                    response = task.response as? HTTPURLResponse
                    determineStatus(with: .statusCode(statusCode))
                } else {
                    resumeData = nil
                    succeeded(fromRunning: true, immediately: true)
                }
            default:
                return
            }
        }
    }

}



extension Array where Element == DownloadTask {
    @discardableResult
    public func progress(onMainQueue: Bool = true, handler: @escaping Handler<DownloadTask>) -> [Element] {
        self.forEach { $0.progress(onMainQueue: onMainQueue, handler: handler) }
        return self
    }

    @discardableResult
    public func success(onMainQueue: Bool = true, handler: @escaping Handler<DownloadTask>) -> [Element] {
        self.forEach { $0.success(onMainQueue: onMainQueue, handler: handler) }
        return self
    }

    @discardableResult
    public func failure(onMainQueue: Bool = true, handler: @escaping Handler<DownloadTask>) -> [Element] {
        self.forEach { $0.failure(onMainQueue: onMainQueue, handler: handler) }
        return self
    }

    public func validateFile(codes: [String],
                             type: FileChecksumHelper.VerificationType,
                             onMainQueue: Bool = true,
                             handler: @escaping Handler<DownloadTask>) -> [Element] {
        for (index, task) in self.enumerated() {
            guard let code = codes.safeObject(at: index) else { continue }
            task.validateFile(code: code, type: type, onMainQueue: onMainQueue, handler: handler)
        }
        return self
    }
}
