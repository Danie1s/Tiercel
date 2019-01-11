//
//  TRDownloadTask.swift
//  Tiercel
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018年 Daniels. All rights reserved.
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

public class TRDownloadTask: TRTask {

    private var task: URLSessionDownloadTask?
    
    internal var location: URL?
    
    var resumeData: Data? {
        didSet {
            guard let resumeData = resumeData else { return  }
            tmpFileName = TRResumeDataHelper.getTmpFileName(resumeData)
        }
    }
    
    var tmpFileName: String?

    public init(_ url: URL, fileName: String? = nil, cache: TRCache, progressHandler: TRTaskHandler? = nil, successHandler: TRTaskHandler? = nil, failureHandler: TRTaskHandler? = nil) {
        super.init(url, cache: cache, progressHandler: progressHandler, successHandler: successHandler, failureHandler: failureHandler)
        if let fileName = fileName {
            if !fileName.isEmpty {
                self.fileName = fileName
            }
        }
    }
    
    public override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(resumeData, forKey: "resumeData")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        resumeData = aDecoder.decodeObject(forKey: "resumeData") as? Data
    }
    
    
    internal override func start() {
        cache.createDirectory()
        
        if let resumeData = resumeData {
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
        
        task?.addObserver(self, forKeyPath: "currentRequest", options: [.new], context: nil)
        task?.resume()
        if startDate == 0 {
            startDate = Date().timeIntervalSince1970
        }
        status = .running

    }



    
    internal override func suspend() {
        guard status == .running || status == .waiting else { return }
        TiercelLog("[downloadTask] did suspend \(self.URLString)")

        if status == .running {
            status = .willSuspend
            task?.cancel(byProducingResumeData: { _ in })
        }

        if status == .waiting {
            status = .suspended
            DispatchQueue.main.tr.safeAsync {
                self.progressHandler?(self)
                self.successHandler?(self)
            }
            manager?.completed()
        }
    }
    
    internal override func cancel() {
        guard status != .completed else { return }
        TiercelLog("[downloadTask] did cancel \(self.URLString)")
        if status == .running {
            status = .willCancel
            task?.cancel()
        } else {
            status = .willCancel
            manager?.taskDidCancelOrRemove(URLString)
            DispatchQueue.main.tr.safeAsync {
                self.failureHandler?(self)
            }
            manager?.completed()
        }
        
    }


    internal override func remove() {
        TiercelLog("[downloadTask] did remove \(self.URLString)")
        if status == .running {
            status = .willRemove
            task?.cancel()
        } else {
            status = .willRemove
            manager?.taskDidCancelOrRemove(URLString)
            DispatchQueue.main.tr.safeAsync {
                self.failureHandler?(self)
            }
            manager?.completed()
        }
    }
    
    internal override func completed() {
        guard status != .completed else { return }
        status = .completed
        endDate = Date().timeIntervalSince1970
        progress.completedUnitCount = progress.totalUnitCount
        timeRemaining = 0
        TiercelLog("[downloadTask] a task did complete URLString: \(URLString)")
        DispatchQueue.main.tr.safeAsync {
            self.progressHandler?(self)
            self.successHandler?(self)
        }

    }

}

// MARK: - KVO
extension TRDownloadTask {
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let change = change, let newRequest = change[NSKeyValueChangeKey.oldKey] as? URLRequest, let url = newRequest.url {
            currentURLString = url.absoluteString
        }
    }
}

// MARK: - info
extension TRDownloadTask {

    internal func parseSpeed(_ cost: TimeInterval) {

        let dataCount = progress.completedUnitCount
        let lastData: Int64 = progress.userInfo[.fileCompletedCountKey] as? Int64 ?? 0

        if dataCount > lastData {
            speed = Int64(Double(dataCount - lastData) / cost)
            parseTimeRemaining()
        }

        progress.setUserInfoObject(dataCount, forKey: .fileCompletedCountKey)

    }

    private func parseTimeRemaining() {
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
extension TRDownloadTask {
    public func task(didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress.completedUnitCount = totalBytesWritten
        progress.totalUnitCount = totalBytesExpectedToWrite
        manager?.parseSpeed()
        DispatchQueue.main.tr.safeAsync {
            if TRManager.isControlNetworkActivityIndicator {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
            self.progressHandler?(self)
            guard let manager = self.manager else { return }
            manager.progressHandler?(manager)
        }
    }
    
    
    public func task(didFinishDownloadingTo location: URL) {
        self.location = location
        cache.storeFile(self)
        completed()
    }
    
    public func task(didCompleteWithError error: Error?) {
        if TRManager.isControlNetworkActivityIndicator {
            DispatchQueue.main.tr.safeAsync {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }
        
        session = nil
        

        
        if let error = error {
            self.error = error
            if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                self.resumeData = TRResumeDataHelper.handleResumeData(resumeData)
                TiercelLog("获得resumeData")
                let dict = TRResumeDataHelper.getResumeDictionary(self.resumeData!)
                TiercelLog(dict)

            }
            
            switch status {
            case .willSuspend:
                status = .suspended
                DispatchQueue.main.tr.safeAsync {
                    self.progressHandler?(self)
                    self.successHandler?(self)
                }
            case .willCancel, .willRemove:
                manager?.taskDidCancelOrRemove(URLString)
                DispatchQueue.main.tr.safeAsync {
                    self.failureHandler?(self)
                }
            default:
                status = .failed
                DispatchQueue.main.tr.safeAsync {
                    self.failureHandler?(self)
                }
            }
        }
        
        manager?.completed()
    }
}


