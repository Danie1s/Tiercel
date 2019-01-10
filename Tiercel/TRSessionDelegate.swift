//
//  TRSessionDelegate.swift
//  BackgroundURLSession
//
//  Created by Daniels Lau on 2019/1/3.
//  Copyright © 2019 Daniels Lau. All rights reserved.
//

import UIKit

internal class TRSessionDelegate: NSObject {
    internal var manager: TRManager?

}


extension TRSessionDelegate: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        manager?.manager(session, didBecomeInvalidWithError: error)
    }
    
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        manager?.managerDidFinishEvents(forBackgroundURLSession: session)
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let manager = manager,
            let URLString = downloadTask.originalRequest?.url?.absoluteString,
            let task = manager.fetchTask(URLString) as? TRDownloadTask
            else { return  }
        task.task(didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
    
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let manager = manager,
            let URLString = downloadTask.originalRequest?.url?.absoluteString,
            let task = manager.fetchTask(URLString) as? TRDownloadTask
            else { return  }
        task.task(didFinishDownloadingTo: location)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let manager = manager,
            let URLString = task.originalRequest?.url?.absoluteString,
            let task = manager.fetchTask(URLString) as? TRDownloadTask
            else { return  }
        task.task(didCompleteWithError: error)
    }
    
    
}
