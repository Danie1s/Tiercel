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
    }

    fileprivate var acceptableStatusCodes: Range<Int> { return 200..<300 }
    
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
        set { protectedDownloadState.read { _ in _sessionTask = newValue }}
    }
    
    public var originalRequest: URLRequest? {
        sessionTask?.originalRequest
    }

    public var currentRequest: URLRequest? {
        sessionTask?.currentRequest
    }

    public var response: URLResponse? {
        sessionTask?.response
    }
    
    public var statusCode: Int? {
        (sessionTask?.response as? HTTPURLResponse)?.statusCode
    }

    public var filePath: String {
        return cache.filePath(fileName: fileName)!
    }

    public var pathExtension: String? {
        let pathExtension = (filePath as NSString).pathExtension
        return pathExtension.isEmpty ? nil : pathExtension
    }

    internal var tmpFileURL: URL?


    private struct DownloadState {
        var resumeData: Data? {
            didSet {
                guard let resumeData = resumeData else { return }
                tmpFileName = ResumeDataHelper.getTmpFileName(resumeData)
            }
        }
        var tmpFileName: String?
        var shouldValidateFile: Bool = false
    }
    
    private let protectedDownloadState: Protector<DownloadState> = Protector(DownloadState())
    
    
    private var resumeData: Data? {
        get { protectedDownloadState.directValue.resumeData }
        set { protectedDownloadState.write { $0.resumeData = newValue } }
    }
    
    internal var tmpFileName: String? {
        protectedDownloadState.directValue.tmpFileName
    }

    fileprivate var shouldValidateFile: Bool {
        get { protectedDownloadState.directValue.shouldValidateFile }
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
    }
    
    internal required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        resumeData = try container.decodeIfPresent(Data.self, forKey: .resumeData)
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

    internal func prepareForDownload() {
        cache.createDirectory()

        if cache.fileExists(fileName: fileName) {
            manager?.log(.downloadTask("file already exists", task: self))
            if let fileInfo = try? FileManager.default.attributesOfItem(atPath: cache.filePath(fileName: fileName)!),
                let length = fileInfo[.size] as? Int64 {
                progress.totalUnitCount = length
            }
            succeeded()
            manager?.determineStatus()
            return
        }
        download()
    }

    private func download() {
        guard let manager = manager else { return }
        switch status {
        case .waiting, .suspended, .failed:
            if manager.shouldRun {
                start()
            } else {
                status = .waiting
            }
        case .succeeded:
            succeeded()
            manager.determineStatus()
        case .running:
            status = .running
        default: break
        }
    }


    private func start() {
        if let resumeData = resumeData {
            cache.retrieveTmpFile(self)
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
        }
        let tempStartDate = startDate
        status = .running
        protectedState.write {
            $0.speed = 0
            if tempStartDate == 0 {
                 $0.startDate = Date().timeIntervalSince1970
            }
        }
        progress.setUserInfoObject(progress.completedUnitCount, forKey: .fileCompletedCountKey)
        error = nil
        sessionTask?.resume()
        progressExecuter?.execute(self)
        manager?.didStart()
    }


    internal func suspend(onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        guard status == .running || status == .waiting else { return }
        controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)

        if status == .running {
            status = .willSuspend
            sessionTask?.cancel(byProducingResumeData: { _ in })
        }

        if status == .waiting {
            status = .suspended
            progressExecuter?.execute(self)
            executeControl()
            executeCompletion(false)

            manager?.determineStatus()
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
            didCancelOrRemove()
            executeControl()
            executeCompletion(false)
            manager?.determineStatus()
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
            didCancelOrRemove()
            executeControl()
            executeCompletion(false)
            manager?.determineStatus()
        }
    }


    internal func update(_ newHeaders: [String: String]? = nil, newFileName: String? = nil, newStatus: Status? = nil) {
        headers = newHeaders
        if let newFileName = newFileName, !newFileName.isEmpty {
            cache.updateFileName(self, newFileName)
            fileName = newFileName
        }
        if let newStatus = newStatus {
            status = newStatus
        }
    }

    fileprivate func validateFile() {
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


    internal func succeeded() {
        guard status != .succeeded else { return }
        status = .succeeded
        protectedState.write {
            $0.endDate = Date().timeIntervalSince1970
            $0.timeRemaining = 0
        }
        progress.completedUnitCount = progress.totalUnitCount
        progressExecuter?.execute(self)
        executeCompletion(true)
        validateFile()
    }

    private func determineStatus(with error: Error?) {
        var tempStatus = status

        if let error = error {
            self.error = error

            if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                self.resumeData = ResumeDataHelper.handleResumeData(resumeData)
                cache.storeTmpFile(self)
            }
            if let _ = (error as NSError).userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int {
                tempStatus = .suspended
            }
            if let urlError = error as? URLError, urlError.code != URLError.cancelled {
                tempStatus = .failed
            }
        } else {
            self.error = TiercelError.unacceptableStatusCode(code: statusCode ?? -1)
            tempStatus = .failed
        }
        status = tempStatus

        switch status {
        case .suspended:
            status = .suspended

        case .willSuspend:
            status = .suspended
            progressExecuter?.execute(self)
            executeControl()
            executeCompletion(false)
        case .willCancel, .willRemove:
            didCancelOrRemove()
            executeControl()
            executeCompletion(false)
        case .failed:
            progressExecuter?.execute(self)
            executeCompletion(false)
        default:
            status = .failed
            progressExecuter?.execute(self)
            executeCompletion(false)
        }
    }
}

// MARK: - closure
extension DownloadTask {
    @discardableResult
    public func validateFile(code: String,
                             type: FileVerificationType,
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

    internal func updateSpeedAndTimeRemaining(_ interval: TimeInterval) {

        let dataCount = progress.completedUnitCount
        let lastData: Int64 = progress.userInfo[.fileCompletedCountKey] as? Int64 ?? 0

        if dataCount > lastData {
            let speed = Int64(Double(dataCount - lastData) / interval)
            updateTimeRemaining(speed)
        }
        progress.setUserInfoObject(dataCount, forKey: .fileCompletedCountKey)

    }

    private func updateTimeRemaining(_ speed: Int64) {
        var timeRemaining: Double
        if speed == 0 {
            timeRemaining = 0
        } else {
            timeRemaining = (Double(progress.totalUnitCount) - Double(progress.completedUnitCount)) / Double(speed)
            if (0.8..<1).contains(timeRemaining) {
                timeRemaining += 1
            }
        }
        self.speed = speed
        self.timeRemaining = Int64(timeRemaining)
    }
}

// MARK: - callback
extension DownloadTask {
    internal func didWriteData(bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress.completedUnitCount = totalBytesWritten
        progress.totalUnitCount = totalBytesExpectedToWrite
        progressExecuter?.execute(self)
        manager?.updateProgress()
    }
    
    
    internal func didFinishDownloading(task: URLSessionDownloadTask, to location: URL) {
        guard let statusCode = (task.response as? HTTPURLResponse)?.statusCode,
            acceptableStatusCodes.contains(statusCode)
            else { return }
        self.tmpFileURL = location
        cache.storeFile(self)
        cache.removeTmpFile(self)
    }
    
    internal func didComplete(task: URLSessionTask, error: Error?) {
        progress.totalUnitCount = task.countOfBytesExpectedToReceive
        progress.completedUnitCount = task.countOfBytesReceived
        progress.setUserInfoObject(task.countOfBytesReceived, forKey: .fileCompletedCountKey)

        let statusCode = (task.response as? HTTPURLResponse)?.statusCode ?? -1
        let isAcceptable = acceptableStatusCodes.contains(statusCode)

        if error == nil && isAcceptable {
            succeeded()
        } else {
            determineStatus(with: error)
        }
        manager?.determineStatus()
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
                             type: FileVerificationType,
                             onMainQueue: Bool = true,
                             handler: @escaping Handler<DownloadTask>) -> [Element] {
        for (index, task) in self.enumerated() {
            guard let code = codes.safeObject(at: index) else { continue }
            task.validateFile(code: code, type: type, onMainQueue: onMainQueue, handler: handler)
        }
        return self
    }
}
