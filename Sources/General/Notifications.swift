//
//  Notifications.swift
//  Tiercel
//
//  Created by Daniels on 2020/1/20.
//  Copyright © 2020 Daniels. All rights reserved.
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

public extension DownloadTask {

    static let runningNotification = Notification.Name(rawValue: "com.Tiercel.notification.name.downloadTask.running")
    static let didCompleteNotification = Notification.Name(rawValue: "com.Tiercel.notification.name.downloadTask.didComplete")
 
}

public extension SessionManager {

    static let runningNotification = Notification.Name(rawValue: "com.Tiercel.notification.name.sessionManager.running")
    static let didCompleteNotification = Notification.Name(rawValue: "com.Tiercel.notification.name.sessionManager.didComplete")
    
}

extension Notification: TiercelCompatible { }
extension TiercelWrapper where Base == Notification {
    public var downloadTask: DownloadTask? {
        return base.userInfo?[String.downloadTaskKey] as? DownloadTask
    }
    
    public var sessionManager: SessionManager? {
        return base.userInfo?[String.sessionManagerKey] as? SessionManager
    }
}

extension Notification {
    init(name: Notification.Name, downloadTask: DownloadTask) {
        self.init(name: name, object: nil, userInfo: [String.downloadTaskKey: downloadTask])
    }
    
    init(name: Notification.Name, sessionManager: SessionManager) {
        self.init(name: name, object: nil, userInfo: [String.sessionManagerKey: sessionManager])
    }
}

extension NotificationCenter {

    func postNotification(name: Notification.Name, downloadTask: DownloadTask) {
        let notification = Notification(name: name, downloadTask: downloadTask)
        post(notification)
    }
    
    func postNotification(name: Notification.Name, sessionManager: SessionManager) {
        let notification = Notification(name: name, sessionManager: sessionManager)
        post(notification)
    }
}

extension String {
    
    fileprivate static let downloadTaskKey = "com.Tiercel.notification.key.downloadTask"
    fileprivate static let sessionManagerKey = "com.Tiercel.notification.key.sessionManagerKey"

}
