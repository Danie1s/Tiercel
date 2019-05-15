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
    
    internal var task: URLSessionDownloadTask? {
        willSet {
            task?.removeObserver(self, forKeyPath: "currentRequest")
        }
        didSet {
            task?.addObserver(self, forKeyPath: "currentRequest", options: [.new], context: nil)
        }
    }

    public var filePath: String {
        return cache.filePath(fileName: fileName)!
    }

    public var pathExtension: String? {
        let pathExtension = (filePath as NSString).pathExtension
        return pathExtension.isEmpty ? nil : pathExtension
    }

    internal var tmpFileURL: URL?
    
    internal var tmpFileName: String?

    private var _resumeData: Data? {
        didSet {
            guard let resumeData = _resumeData else { return  }
            tmpFileName = ResumeDataHelper.getTmpFileName(resumeData)
        }
    }
    private var resumeData: Data? {
        get {
            return dataQueue.sync {
                _resumeData
            }
        }
        set {
            dataQueue.sync {
                _resumeData = newValue
            }
        }
    }

    private var _shouldValidateFile: Bool = false
    fileprivate var shouldValidateFile: Bool {
        get {
            return dataQueue.sync {
                _shouldValidateFile
            }
        }
        set {
            dataQueue.sync {
                _shouldValidateFile = newValue
            }
        }
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
        if let fileName = fileName,
            !fileName.isEmpty {
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
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        resumeData = try container.decodeIfPresent(Data.self, forKey: .resumeData)
        guard let resumeData = resumeData else { return }
        tmpFileName = ResumeDataHelper.getTmpFileName(resumeData)
    }
    
    @available(*, deprecated, message: "Use encode(to:) instead.")
    public override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(resumeData, forKey: "resumeData")
    }
    
    @available(*, deprecated, message: "Use init(from:) instead.")
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        resumeData = aDecoder.decodeObject(forKey: "resumeData") as? Data
        guard let resumeData = resumeData else { return  }
        tmpFileName = ResumeDataHelper.getTmpFileName(resumeData)
    }
    
    deinit {
        task?.removeObserver(self, forKeyPath: "currentRequest")
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func fixDelegateMethodError() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.task?.suspend()
            self.task?.resume()
        }
    }
    
// MARK: - control
    internal override func start() {
        cache.createDirectory()
        
        if cache.fileExists(fileName: fileName) {
            TiercelLog("[downloadTask] file already exists", identifier: manager?.identifier ?? "", url: url)
            if let fileInfo = try? FileManager().attributesOfItem(atPath: cache.filePath(fileName: fileName)!), let length = fileInfo[.size] as? Int64 {
                progress.totalUnitCount = length
            }
            completed()
            manager?.completed()
            return
        }
        prepareToStart()
    }
    

    internal func suspend(onMainQueue: Bool = true, _ handler: Handler<DownloadTask>? = nil) {
        guard status == .running || status == .waiting else { return }
        controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)

        if status == .running {
            status = .willSuspend
            task?.cancel(byProducingResumeData: { _ in })
        }

        if status == .waiting {
            status = .suspended
            TiercelLog("[downloadTask] did suspend", identifier: manager?.identifier ?? "", url: url)
            progressExecuter?.execute(self)
            controlExecuter?.execute(self)
            failureExecuter?.execute(self)

            manager?.completed()
        }
    }
    
    internal func cancel(onMainQueue: Bool = true, _ handler: Handler<DownloadTask>? = nil) {
        guard status != .succeeded else { return }
        controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        if status == .running {
            status = .willCancel
            task?.cancel()
        } else {
            status = .willCancel
            didCancelOrRemove()
            TiercelLog("[downloadTask] did cancel", identifier: manager?.identifier ?? "", url: url)
            controlExecuter?.execute(self)
            failureExecuter?.execute(self)
            manager?.completed()
        }
    }


    internal func remove(completely: Bool = false, onMainQueue: Bool = true, _ handler: Handler<DownloadTask>? = nil) {
        self.isRemoveCompletely = completely
        controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        if status == .running {
            status = .willRemove
            task?.cancel()
        } else {
            status = .willRemove
            didCancelOrRemove()
            TiercelLog("[downloadTask] did remove", identifier: manager?.identifier ?? "", url: url)
            controlExecuter?.execute(self)
            failureExecuter?.execute(self)
            manager?.completed()
        }
    }
    
    internal func completed() {
        guard status != .succeeded else { return }
        status = .succeeded
        endDate = Date().timeIntervalSince1970
        progress.completedUnitCount = progress.totalUnitCount
        timeRemaining = 0
        TiercelLog("[downloadTask] completed", identifier: manager?.identifier ?? "", url: url)
        progressExecuter?.execute(self)
        successExecuter?.execute(self)
        validateFile()
    }
    
    override func executeHandler(_ executer: Executer<DownloadTask>?) {
        executer?.execute(self)
    }


    fileprivate func validateFile() {
        guard let validateHandler = self.validateExecuter else { return }

        if !shouldValidateFile {
            validateHandler.execute(self)
            return
        }

        guard let verificationCode = verificationCode else { return }
        FileChecksumHelper.validateFile(filePath, code: verificationCode, type: verificationType) { [weak self] (isCorrect) in
            guard let self = self else { return }
            self.shouldValidateFile = false
            self.validation = isCorrect ? .correct : .incorrect
            if let manager = self.manager {
                manager.cache.storeTasks(manager.tasks)
            }
            validateHandler.execute(self)
        }
    }
}

extension DownloadTask {
    internal func updateFileName(_ newFileName: String) {
        guard !fileName.isEmpty else { return }
        cache.updateFileName(self, newFileName)
        fileName = newFileName
    }
}

// MARK: - status handle
extension DownloadTask {
    private func prepareToStart() {
        guard let manager = manager else { return }
        switch status {
        case .waiting, .suspended, .failed:
            if manager.shouldRun {
                startToDownload()
            } else {
                status = .waiting
                TiercelLog("[downloadTask] waiting", identifier: manager.identifier, url: url)
            }
        case .succeeded:
            completed()
            manager.completed()
        case .running:
            TiercelLog("[downloadTask] running", identifier: manager.identifier, url: url)
        default: break
        }
    }
    
    private func startToDownload() {
        
        if let resumeData = resumeData {
            cache.retrieveTmpFile(self)
            if #available(iOS 10.2, *) {
                task = session?.downloadTask(withResumeData: resumeData)
            } else if #available(iOS 10.0, *) {
                task = session?.correctedDownloadTask(withResumeData: resumeData)
            } else {
                task = session?.downloadTask(withResumeData: resumeData)
            }
        } else {
            super.start()
            guard let request = request else { return  }
            task = session?.downloadTask(with: request)
        }
        speed = 0
        progress.setUserInfoObject(progress.completedUnitCount, forKey: .fileCompletedCountKey)
        
        task?.resume()
        
        if startDate == 0 {
            startDate = Date().timeIntervalSince1970
        }
        status = .running
        TiercelLog("[downloadTask] running", identifier: manager?.identifier ?? "", url: url)
        progressExecuter?.execute(self)
        manager?.didStart()
    }
    
    private func didCancelOrRemove() {
        
        // 把预操作的状态改成完成操作的状态
        if status == .willCancel {
            status = .canceled
        }
        
        if status == .willRemove {
            status = .removed
        }
        cache.remove(self, completely: isRemoveCompletely)
        
        manager?.didCancelOrRemove(url.absoluteString)
    }
}

// MARK: - closure
extension DownloadTask {
    @discardableResult
    public func validateFile(code: String,
                             type: FileVerificationType,
                             onMainQueue: Bool = true,
                             _ handler: @escaping Handler<DownloadTask>) -> Self {
        return operationQueue.sync {
            if verificationCode == code &&
                verificationType == type &&
                validation != .unkown {
                shouldValidateFile = false
            } else {
                shouldValidateFile = true
                verificationCode = code
                verificationType = type
            }
            self.validateExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            if let manager = manager {
                manager.cache.storeTasks(manager.tasks)
            }
            if status == .succeeded {
                validateFile()
            }
            return self
        }

    }
}



// MARK: - KVO
extension DownloadTask {
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let change = change, let newRequest = change[NSKeyValueChangeKey.newKey] as? URLRequest, let url = newRequest.url {
            currentURL = url
        }
    }
}

// MARK: - info
extension DownloadTask {

    internal func updateSpeedAndTimeRemaining(_ interval: TimeInterval) {

        let dataCount = progress.completedUnitCount
        let lastData: Int64 = progress.userInfo[.fileCompletedCountKey] as? Int64 ?? 0

        if dataCount > lastData {
            speed = Int64(Double(dataCount - lastData) / interval)
            updateTimeRemaining()
        }
        progress.setUserInfoObject(dataCount, forKey: .fileCompletedCountKey)

    }

    private func updateTimeRemaining() {
        if speed == 0 {
            self.timeRemaining = 0
        } else {
            let timeRemaining = (Double(progress.totalUnitCount) - Double(progress.completedUnitCount)) / Double(speed)
            self.timeRemaining = Int64(timeRemaining)
            if timeRemaining < 1 && timeRemaining > 0.8 {
                self.timeRemaining += 1
            }
        }
    }
}

// MARK: - download callback
extension DownloadTask {
    internal func didWriteData(bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress.completedUnitCount = totalBytesWritten
        progress.totalUnitCount = totalBytesExpectedToWrite
        if SessionManager.isControlNetworkActivityIndicator {
            DispatchQueue.main.tr.safeAsync {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
        }
        progressExecuter?.execute(self)
        manager?.updateProgress()
    }
    
    
    internal func didFinishDownloadingTo(location: URL) {
        self.tmpFileURL = location
        cache.storeFile(self)
        cache.removeTmpFile(self)
    }
    
    internal func didComplete(task: URLSessionTask, error: Error?) {
        if SessionManager.isControlNetworkActivityIndicator {
            DispatchQueue.main.tr.safeAsync {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }

        progress.totalUnitCount = task.countOfBytesExpectedToReceive
        progress.completedUnitCount = task.countOfBytesReceived
        progress.setUserInfoObject(task.countOfBytesReceived, forKey: .fileCompletedCountKey)

        if let error = error {
            self.error = error
        
            if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                self.resumeData = ResumeDataHelper.handleResumeData(resumeData)
                cache.storeTmpFile(self)
            }
            if let _ = (error as NSError).userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int {
                status = .suspended
            }
            if let urlError = error as? URLError, urlError.code != URLError.cancelled {
                status = .failed
            }
            
            switch status {
            case .suspended:
                status = .suspended
                TiercelLog("[downloadTask] did suspend", identifier: manager?.identifier ?? "", url: url)

            case .willSuspend:
                status = .suspended
                TiercelLog("[downloadTask] did suspend", identifier: manager?.identifier ?? "", url: url)
                progressExecuter?.execute(self)
                controlExecuter?.execute(self)
                failureExecuter?.execute(self)
            case .willCancel, .willRemove:
                didCancelOrRemove()
                if status == .canceled {
                    TiercelLog("[downloadTask] did cancel", identifier: manager?.identifier ?? "", url: url)
                }
                if status == .removed {
                    TiercelLog("[downloadTask] did remove", identifier: manager?.identifier ?? "", url: url)
                }
                controlExecuter?.execute(self)
                failureExecuter?.execute(self)
            default:
                status = .failed
                TiercelLog("[downloadTask] failed", identifier: manager?.identifier ?? "", url: url)
                progressExecuter?.execute(self)
                failureExecuter?.execute(self)
            }
        } else {
            completed()
        }
        manager?.completed()
    }
}

extension Array where Element == DownloadTask {
    @discardableResult
    public func progress(onMainQueue: Bool = true, _ handler: @escaping Handler<DownloadTask>) -> [Element] {
        self.forEach { $0.progress(onMainQueue: onMainQueue, handler) }
        return self
    }

    @discardableResult
    public func success(onMainQueue: Bool = true, _ handler: @escaping Handler<DownloadTask>) -> [Element] {
        self.forEach { $0.success(onMainQueue: onMainQueue, handler) }
        return self
    }

    @discardableResult
    public func failure(onMainQueue: Bool = true, _ handler: @escaping Handler<DownloadTask>) -> [Element] {
        self.forEach { $0.failure(onMainQueue: onMainQueue, handler) }
        return self
    }

    public func validateFile(codes: [String],
                             type: FileVerificationType,
                             onMainQueue: Bool = true,
                             _ handler: @escaping Handler<DownloadTask>) -> [Element] {
        for (index, task) in self.enumerated() {
            guard let code = codes.safeObject(at: index) else { continue }
            task.validateFile(code: code, type: type, onMainQueue: onMainQueue, handler)
        }
        return self
    }
}
