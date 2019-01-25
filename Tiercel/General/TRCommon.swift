//
//  TRCommon.swift
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


public enum TRStatus: String {
    case waiting
    case running
    case suspended
    case canceled
    case failed
    case removed
    case succeeded

    // 预操作标记，解决操作运行中的任务是异步回调而导致的问题
    case willSuspend
    case willCancel
    case willRemove
}


public enum TRLogLevel {
    case detailed
    case simple
    case none
}


public typealias TRTaskHandler = (TRTask) -> ()
public typealias TRManagerHandler = (TRManager) -> ()

public class Tiercel<Base> {
    internal let base: Base
    internal init(_ base: Base) {
        self.base = base
    }
}


public protocol TiercelCompatible {
    associatedtype CompatibleType
    var tr: CompatibleType { get }
}


extension TiercelCompatible {
    public var tr: Tiercel<Self> {
        get { return Tiercel(self) }
    }
}


public func TiercelLog<T>(_ message: T, file: String = #file, method: String = #function, line: Int = #line) {

    switch TRManager.logLevel {
    case .detailed:
        print("")
        print("***************TiercelLog****************")
        let threadNum = (Thread.current.description as NSString).components(separatedBy: "{").last?.components(separatedBy: ",").first ?? ""

        print("source  :  \((file as NSString).lastPathComponent)[\(line)]\n" +
            "Thread  :  \(threadNum)\n" +
            "Info    :  \(message)"
        )
        print("")
    case .simple: print(message)
    case .none: break
    }
}

