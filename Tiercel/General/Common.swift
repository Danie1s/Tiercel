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


public enum LogLevel {
    case detailed
    case simple
    case none
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
        get { return TiercelWrapper(self) }
    }
}


public func TiercelLog<T>(_ message: T, identifier: String? = nil, url: URLConvertible? = nil, file: String = #file, line: Int = #line) {

    switch SessionManager.logLevel {
    case .detailed:
        print("***************TiercelLog****************")
        let threadNum = (Thread.current.description as NSString).components(separatedBy: "{").last?.components(separatedBy: ",").first ?? ""

        var log =  "Source     :  \((file as NSString).lastPathComponent)[\(line)]\n" +
                   "Thread     :  \(threadNum)\n"
        if let identifier = identifier {
            log += "identifier :  \(identifier)\n"
        }
        if let url = url {
            log += "url        :  \(url)\n"
        }
        log +=     "Info       :  \(message)"
        print(log)
        print("")
    case .simple: print(message)
    case .none: break
    }
}

