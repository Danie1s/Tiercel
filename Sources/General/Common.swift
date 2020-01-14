//
//  Common.swift
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


public enum LogOption {
    case `default`
    case none
}

public enum LogType {
    case sessionManager(_ message: String, manager: SessionManager)
    case downloadTask(_ message: String, task: DownloadTask)
    case error(_ message: String, error: Error)
}

public protocol Logable {
    var identifier: String { get }
    
    var option: LogOption { get set }
    
    func log(_ type: LogType)
}

public struct Logger: Logable {
    
    public let identifier: String
    
    public var option: LogOption
    
    public func log(_ type: LogType) {
        guard option == .default else { return }
        var strings = ["************************ TiercelLog ************************"]
        strings.append("identifier    :  \(identifier)")
        switch type {
        case let .sessionManager(message, manager):
            strings.append("Message       :  [SessionManager] \(message), tasks.count: \(manager.tasks.count)")
        case let .downloadTask(message, task):
            strings.append("Message       :  [DownloadTask] \(message)")
            strings.append("Task URL      :  \(task.url.absoluteString)")
            if let error = task.error, task.status == .failed {
                strings.append("Error         :  \(error)")
            }
        case let .error(message, error):
            strings.append("Message       :  [Error] \(message)")
            strings.append("Description   :  \(error)")
        }
        strings.append("")
        print(strings.joined(separator: "\n"))
    }
}

public enum Status: String {
    case waiting
    case running
    case suspended
    case canceled
    case failed
    case removed
    case succeeded

    case willSuspend
    case willCancel
    case willRemove
}

public struct TiercelWrapper<Base> {
    internal let base: Base
    internal init(_ base: Base) {
        self.base = base
    }
}


public protocol TiercelCompatible {

}

extension TiercelCompatible {
    public var tr: TiercelWrapper<Self> {
        get { TiercelWrapper(self) }
    }
    public static var tr: TiercelWrapper<Self>.Type {
        get { TiercelWrapper<Self>.self }
    }
}

