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
    case sessionManager(_ manager: SessionManager, message: String)
    case downloadTask(_ task: DownloadTask, message: String)
    case error(_ error: Error, message: String)
}

public protocol Logable: AnyObject {
    var identifier: String { get }
    
    var option: LogOption { get set }
    
    func log(_ type: LogType)
}

public class Logger: Logable {
    
    public let identifier: String
    
    public var option: LogOption
    
    init(identifier: String, option: LogOption = .default) {
        self.identifier = identifier
        self.option = option
    }
    
    public func log(_ type: LogType) {
        guard option == .default else { return }
        var strings = ["************************ TiercelLog ************************"]
        strings.append("identifier    :  \(identifier)")
        switch type {
            case let .sessionManager(manager, message):
                strings.append("Message       :  [SessionManager] \(message), tasks.count: \(manager.tasks.count)")
            case let .downloadTask(task, message):
                strings.append("Message       :  [DownloadTask] \(message)")
                strings.append("Task URL      :  \(task.url.absoluteString)")
                if let error = task.error, task.status == .failed {
                    strings.append("Error         :  \(error)")
                }
            case let .error(error, message):
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
    let base: Base
    init(_ base: Base) {
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

