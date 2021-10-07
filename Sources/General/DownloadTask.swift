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

public protocol DownloadTaskDelegate: TaskDelegate {
    func downloadTaskFileExists(_ task: DownloadTask)
        
    func downloadTaskWillValidateFile(_ task: DownloadTask)
    
    func downloadTaskDidValidateFile(_ task: DownloadTask, result: Result<Bool, FileChecksumHelper.FileVerificationError>)
        
}

public class DownloadTask: Task<DownloadTask> {
    
    private enum CodingKeys: CodingKey {
        case resumeData
        case response
    }

    private var acceptableStatusCodes: Range<Int> { return 200..<300 }
    

    public var response: HTTPURLResponse? {
        $mutableDownloadState.read {
            return $0.response ?? $0.downloadTask?.response as? HTTPURLResponse
        }
    }
    

    public var filePath: String {
        return cache.filePath(fileName: fileName)!
    }

    public var pathExtension: String? {
        let pathExtension = (filePath as NSString).pathExtension
        return pathExtension.isEmpty ? nil : pathExtension
    }


    struct MutableDownloadState {
        var resumeData: Data? {
            didSet {
                guard let resumeData = resumeData else { return }
                tmpFileName = ResumeDataHelper.getTmpFileName(resumeData)
            }
        }
        var response: HTTPURLResponse?
        var tmpFileName: String?
        var shouldValidateFile: Bool = false
        var downloadTask: URLSessionDownloadTask?
    }
    
    @Protected
    var mutableDownloadState: MutableDownloadState = MutableDownloadState()
    

    init(_ url: URL,
         headers: [String: String]? = nil,
         fileName: String? = nil,
         cache: Cache,
         operationQueue: DispatchQueue) {
        super.init(url,
                   headers: headers,
                   cache: cache,
                   operationQueue: operationQueue)
        if let fileName = fileName, !fileName.isEmpty {
            self.mutableState.fileName = fileName
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
        try container.encodeIfPresent(mutableDownloadState.resumeData, forKey: .resumeData)
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
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        mutableDownloadState.resumeData = try container.decodeIfPresent(Data.self, forKey: .resumeData)
        if let responseData = try container.decodeIfPresent(Data.self, forKey: .response) {
            if #available(iOS 11.0, *) {
                mutableDownloadState.response = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HTTPURLResponse.self, from: responseData)
            } else {
                mutableDownloadState.response = NSKeyedUnarchiver.unarchiveObject(with: responseData) as? HTTPURLResponse
            }
        }
    }
    
    
    deinit {
        mutableDownloadState.downloadTask?.removeObserver(self, forKeyPath: #keyPath(URLSessionDownloadTask.currentRequest))
        NotificationCenter.default.removeObserver(self)
    }
    
    func restoreRunningStatus(with sessionDownloadTask: URLSessionDownloadTask) {
        mutableState.status = .running
        delegate?.task(self, statusDidChange: .running)
        mutableDownloadState.downloadTask = sessionDownloadTask
    }
    
    @objc private func fixDelegateMethodError() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.$mutableDownloadState.read {
                $0.downloadTask?.suspend()
                $0.downloadTask?.resume()
            }
        }
    }


    override func execute(_ executer: Executer<DownloadTask>?) {
        executer?.execute(self)
    }
    

}


// MARK: - control
extension DownloadTask {

    func tryToDownload(using session: URLSession) {
        cache.createDirectory()
        guard let delegate = delegate else { return }
        switch status {
            case .waiting, .suspended, .failed:
                if cache.fileExists(fileName: fileName) {
                    prepareForDownload(using: session, fileExists: true)
                } else {
                    if delegate.shouldRun {
                        prepareForDownload(using: session, fileExists: false)
                    } else {
                        mutableState.status = .waiting
                        delegate.task(self, statusDidChange: .waiting)
                        mutableState.progressExecuter?.execute(self)
                        executeControl()
                    }
                }
            case .succeeded:
                executeControl()
                succeeded(fromRunning: false)
            case .running:
                mutableState.status = .running
                delegate.task(self, statusDidChange: .running)
                executeControl()
            default: break
        }
    }
    
    private func prepareForDownload(using session: URLSession, fileExists: Bool) {
        $mutableState.write {
            $0.status = .running
            $0.speed = 0
            if $0.startDate == 0 {
                 $0.startDate = Date().timeIntervalSince1970
            }
            $0.error = nil
        }
        delegate?.task(self, statusDidChange: .running)
        mutableDownloadState.response = nil
        start(using: session, fileExists: fileExists)
    }

    private func start(using session: URLSession, fileExists: Bool) {
        if fileExists {
            (delegate as? DownloadTaskDelegate)?.downloadTaskFileExists(self)
            if let fileInfo = try? FileManager.default.attributesOfItem(atPath: cache.filePath(fileName: fileName)!),
                let length = fileInfo[.size] as? Int64 {
                progress.totalUnitCount = length
            }
            executeControl()
            operationQueue.async {
                self.didComplete(.local)
            }
        } else {
            var headers: [String: String]?
            var tmpFileName: String?
            var resumeData: Data?
            var downloadTask: URLSessionDownloadTask?
            $mutableState.read {
                headers = $0.headers
            }
            $mutableDownloadState.read {
                resumeData = $0.resumeData
                tmpFileName = $0.tmpFileName
                downloadTask = $0.downloadTask
            }
            downloadTask?.removeObserver(self,
                                         forKeyPath: #keyPath(URLSessionDownloadTask.currentRequest))
            if let resumeData = resumeData,
                cache.retrieveTmpFile(tmpFileName) {
                if #available(iOS 10.2, *) {
                    downloadTask = session.downloadTask(withResumeData: resumeData)
                } else if #available(iOS 10.0, *) {
                    downloadTask = session.correctedDownloadTask(withResumeData: resumeData)
                } else {
                    downloadTask = session.downloadTask(withResumeData: resumeData)
                }
            } else {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 0)
                if let headers = headers {
                    request.allHTTPHeaderFields = headers
                }
                downloadTask = session.downloadTask(with: request)
                progress.completedUnitCount = 0
                progress.totalUnitCount = 0
            }
            downloadTask?.addObserver(self,
                                      forKeyPath: #keyPath(URLSessionDownloadTask.currentRequest),
                                      options: [.new],
                                      context: nil)
            mutableDownloadState.downloadTask = downloadTask
            progress.setUserInfoObject(progress.completedUnitCount, forKey: .fileCompletedCountKey)
            delegate?.taskDidStart(self)
            executeControl()
            downloadTask?.resume()
        }
    }


    func suspend(onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        guard status == .running || status == .waiting else { return }
        mutableState.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        if status == .running {
            mutableState.status = .willSuspend
            mutableDownloadState.downloadTask?.cancel(byProducingResumeData: { _ in })
        } else {
            mutableState.status = .willSuspend
            operationQueue.async {
                self.didComplete(.local)
            }
        }
    }

    func cancel(onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        guard status != .succeeded else { return }
        mutableState.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        if status == .running {
            mutableState.status = .willCancel
            mutableDownloadState.downloadTask?.cancel()
        } else {
            mutableState.status = .willCancel
            operationQueue.async {
                self.didComplete(.local)
            }
        }
    }

    

    func remove(completely: Bool = false, onMainQueue: Bool = true, handler: Handler<DownloadTask>? = nil) {
        mutableState.isRemoveCompletely = completely
        mutableState.controlExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
        if status == .running {
            mutableState.status = .willRemove
            mutableDownloadState.downloadTask?.cancel()
        } else {
            mutableState.status = .willRemove
            operationQueue.async {
                self.didComplete(.local)
            }
        }
    }


    func update(_ newHeaders: [String: String]? = nil, newFileName: String? = nil) {
        mutableState.headers = newHeaders
        if let newFileName = newFileName, !newFileName.isEmpty {
            cache.updateFileName(filePath, newFileName)
            mutableState.fileName = newFileName
        }
    }

    private func validateFile() {
        guard let validateHandler = mutableState.validateExecuter else { return }

        if !mutableDownloadState.shouldValidateFile {
            validateHandler.execute(self)
            return
        }

        guard let verificationCode = mutableState.verificationCode else { return }

        FileChecksumHelper.validateFile(filePath, code: verificationCode, type: mutableState.verificationType) { [weak self] (result) in
            guard let self = self else { return }
            self.mutableDownloadState.shouldValidateFile = false
            switch result {
                case .success:
                    self.mutableState.validation = .correct
                case .failure:
                    self.mutableState.validation = .incorrect
            }
            (self.delegate as? DownloadTaskDelegate)?.downloadTaskDidValidateFile(self, result: result)
            validateHandler.execute(self)
        }
    }

}



// MARK: - status handle
extension DownloadTask {

    private func didCancelOrRemove() {
        // 把预操作的状态改成完成操作的状态
        
        var newStatus: Status?
        $mutableState.write {
            if $0.status == .willCancel {
                $0.status = .canceled
                newStatus = .canceled
            }
            if $0.status == .willRemove {
                $0.status = .removed
                newStatus = .removed
            }
        }
        if let newStatus = newStatus {
            delegate?.task(self, statusDidChange: newStatus)
        }
        cache.remove(self, completely: mutableState.isRemoveCompletely)
        
        delegate?.taskDidCancelOrRemove(self)
    }


    func succeeded(fromRunning: Bool) {
        $mutableState.write {
            if $0.endDate == 0 {
                $0.endDate = Date().timeIntervalSince1970
                $0.timeRemaining = 0
            }
        }
        progress.completedUnitCount = progress.totalUnitCount
        mutableState.progressExecuter?.execute(self)
        mutableState.status = .succeeded
        delegate?.task(self, statusDidChange: .succeeded)
        executeCompletion(true)
        validateFile()
        delegate?.taskDidSucceed(self, fromRunning: fromRunning)
    }
    
    
    private func determineStatus(with interruptType: InterruptType) {
        var fromRunning = true
        switch interruptType {
            case let .error(error):
                var newStatus: Status?
                if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                    mutableDownloadState.resumeData = ResumeDataHelper.handleResumeData(resumeData)
                    cache.storeTmpFile(mutableDownloadState.tmpFileName)
                }
                if let _ = (error as NSError).userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int {
                    newStatus = .suspended
                }
                if let urlError = error as? URLError, urlError.code != URLError.cancelled {
                    newStatus = .failed
                }
                $mutableState.write {
                    $0.error = error
                    if let newStatus = newStatus {
                        $0.status = newStatus
                    }
                }
                if let newStatus = newStatus {
                    delegate?.task(self, statusDidChange: newStatus)
                }
            case let .statusCode(statusCode):
                $mutableState.write {
                    $0.error = TiercelError.unacceptableStatusCode(code: statusCode)
                    $0.status = .failed
                }
                delegate?.task(self, statusDidChange: .failed)
            case let .manual(fromRunningTask):
                fromRunning = fromRunningTask
        }
        
        switch status {
            case .willSuspend:
                mutableState.status = .suspended
                delegate?.task(self, statusDidChange: .suspended)
                mutableState.progressExecuter?.execute(self)
                executeControl()
                executeCompletion(false)
            case .willCancel, .willRemove:
                didCancelOrRemove()
                executeControl()
                executeCompletion(false)
            case .suspended, .failed:
                mutableState.progressExecuter?.execute(self)
                executeCompletion(false)
            default:
                mutableState.status = .failed
                delegate?.task(self, statusDidChange: .failed)
                mutableState.progressExecuter?.execute(self)
                executeCompletion(false)
        }
        delegate?.taskDidDetermineStatus(self, fromRunning: fromRunning)
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
            let (verificationCode, verificationType) = self.$mutableState.read {
                                                            ($0.verificationCode, $0.verificationType)
                                                        }
            if verificationCode == code &&
                verificationType == type &&
                self.validation != .unkown {
                self.mutableDownloadState.shouldValidateFile = false
            } else {
                self.mutableDownloadState.shouldValidateFile = true
                self.$mutableState.write {
                    $0.verificationCode = code
                    $0.verificationType = type
                }
                (self.delegate as? DownloadTaskDelegate)?.downloadTaskWillValidateFile(self)
            }
             self.mutableState.validateExecuter = Executer(onMainQueue: onMainQueue, handler: handler)
            if self.status == .succeeded {
                self.validateFile()
            }
        }
        return self
    }
    
    private func executeCompletion(_ isSucceeded: Bool) {
        if let completionExecuter = mutableState.completionExecuter {
            completionExecuter.execute(self)
        } else if isSucceeded {
            mutableState.successExecuter?.execute(self)
        } else {
            mutableState.failureExecuter?.execute(self)
        }
        NotificationCenter.default.postNotification(name: DownloadTask.didCompleteNotification, downloadTask: self)
    }
    
    private func executeControl() {
        mutableState.controlExecuter?.execute(self)
        mutableState.controlExecuter = nil
    }
}



// MARK: - KVO
extension DownloadTask {
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(URLSessionDownloadTask.currentRequest),
           let change = change, let newRequest = change[NSKeyValueChangeKey.newKey] as? URLRequest, let url = newRequest.url {
            mutableState.currentURL = url
            delegate?.taskDidUpdateCurrentURL(self)
        }
    }
}

// MARK: - info
extension DownloadTask {

    func updateSpeedAndTimeRemaining() {

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
        $mutableState.write {
            $0.speed = speed
            $0.timeRemaining = Int64(timeRemaining)
        }
    }
}

// MARK: - callback
extension DownloadTask {
    func didWriteData(downloadTask: URLSessionDownloadTask, bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress.completedUnitCount = totalBytesWritten
        progress.totalUnitCount = totalBytesExpectedToWrite
        mutableState.progressExecuter?.execute(self)
        delegate?.taskDidUpdateProgress(self)
        NotificationCenter.default.postNotification(name: DownloadTask.runningNotification, downloadTask: self)
    }
    
    
    func didFinishDownloading(task: URLSessionDownloadTask, to location: URL) {
        guard let statusCode = (task.response as? HTTPURLResponse)?.statusCode,
            acceptableStatusCodes.contains(statusCode)
            else { return }
        cache.storeFile(at: location, to: URL(fileURLWithPath: filePath))
        cache.removeTmpFile(mutableDownloadState.tmpFileName)

    }
    
    func didComplete(_ type: CompletionType) {
        switch type {
            case .local:
                switch status {
                    case .willSuspend,.willCancel, .willRemove:
                        determineStatus(with: .manual(false))
                    case .running:
                        succeeded(fromRunning: false)
                    default:
                        return
                }
            case let .network(task, error):
                delegate?.taskDidCompleteFromRunning(self)
                mutableDownloadState.downloadTask = nil
                
                switch status {
                    case .willCancel, .willRemove:
                        determineStatus(with: .manual(true))
                        
                    case .willSuspend, .running:
                        let response = task.response as? HTTPURLResponse
                        mutableDownloadState.response = response
                        if response != nil {
                            progress.totalUnitCount = task.countOfBytesExpectedToReceive
                            progress.completedUnitCount = task.countOfBytesReceived
                            progress.setUserInfoObject(task.countOfBytesReceived, forKey: .fileCompletedCountKey)
                        }
                        
                        if let error = error {
                            determineStatus(with: .error(error))
                        } else {
                            let statusCode = response?.statusCode ?? -1
                            let isAcceptable = acceptableStatusCodes.contains(statusCode)
                            if isAcceptable {
                                mutableDownloadState.resumeData = nil
                                succeeded(fromRunning: true)
                            } else {
                                determineStatus(with: .statusCode(statusCode))
                            }
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
