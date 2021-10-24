//
//  SessionDelegate.swift
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

protocol SessionStateProvider: AnyObject {
    func task<TaskType, R: Task<TaskType>>(for url: URL, as type: R.Type) -> R?
    
    func didBecomeInvalidation(withError error: Error?)
        
    func didFinishEvents(forBackgroundURLSession session: URLSession)
    
    func log(_ error: Error, message: String)
}

class SessionDelegate: NSObject {
    
    weak var stateProvider: SessionStateProvider?

    func task<TaskType, R: Task<TaskType>>(for url: URL, as type: R.Type) -> R? {
        guard let provider = stateProvider else {
            assertionFailure("StateProvider is nil.")
            return nil
        }

        return provider.task(for: url, as: type)
    }
    
    func handle(_ error: Error, message: String) {
        guard let provider = stateProvider else {
            assertionFailure("StateProvider is nil.")
            return
        }
        provider.log(error, message: message)
    }
}


extension SessionDelegate: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        stateProvider?.didBecomeInvalidation(withError: error)
    }
    
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        stateProvider?.didFinishEvents(forBackgroundURLSession: session)
    }
    
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let currentURL = downloadTask.currentRequest?.url else { return }
        guard let task = task(for: currentURL, as: DownloadTask.self) else {
            handle(TiercelError.fetchDownloadTaskFailed(url: currentURL),
                   message: "urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)")
            return
        }
        task.didWriteData(downloadTask: downloadTask, bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
    
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let currentURL = downloadTask.currentRequest?.url else { return }
        guard let task = task(for: currentURL, as: DownloadTask.self) else {
            handle(TiercelError.fetchDownloadTaskFailed(url: currentURL),
                   message: "urlSession(_:downloadTask:didFinishDownloadingTo:)")
            return
        }
        task.didFinishDownloading(task: downloadTask, to: location)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let currentURL = task.currentRequest?.url {
            guard let downloadTask = self.task(for: currentURL, as: DownloadTask.self) else {
                handle(TiercelError.fetchDownloadTaskFailed(url: currentURL),
                       message: "urlSession(_:task:didCompleteWithError:)")
                return
            }
            downloadTask.didComplete(.network(task: task, error: error))
        } else {
            // url 不合法
            if let error = error {
                if let urlError = error as? URLError,
                   let errorURL = urlError.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
                    guard let downloadTask = self.task(for: errorURL, as: DownloadTask.self) else {
                        handle(TiercelError.fetchDownloadTaskFailed(url: errorURL),
                               message: "urlSession(_:task:didCompleteWithError:)")
                        handle(error, message: "urlSession(_:task:didCompleteWithError:)")
                        return
                    }
                    downloadTask.didComplete(.network(task: task, error: error))
                } else {
                    handle(error, message: "urlSession(_:task:didCompleteWithError:)")
                }
            } else {
                handle(TiercelError.unknown, message: "urlSession(_:task:didCompleteWithError:)")
            }
        }
    }
}
