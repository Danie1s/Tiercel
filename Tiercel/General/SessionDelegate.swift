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

import UIKit

internal class SessionDelegate: NSObject {
    internal weak var manager: SessionManager?

}


extension SessionDelegate: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        manager?.didBecomeInvalidation(withError: error)
    }
    
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        manager?.didFinishEvents(forBackgroundURLSession: session)
    }
    
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let manager = manager,
            let currentURL = downloadTask.currentRequest?.url,
            let task = manager.fetchTask(currentURL: currentURL)
            else { return }
        task.didWriteData(bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
    
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let manager = manager,
            let currentURL = downloadTask.currentRequest?.url,
            let task = manager.fetchTask(currentURL: currentURL)
            else { return }
        task.didFinishDownloadingTo(location: location)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let manager = manager,
            let currentURL = task.currentRequest?.url,
            let downloadTask = manager.fetchTask(currentURL: currentURL)
            else { return }
        downloadTask.didComplete(task: task, error: error)
    }
    
    
}
