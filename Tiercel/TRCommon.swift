//
//  TRCommon.swift
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

public enum TRStatus: String {
    case waiting
    case running
    case suspended
    case canceled
    case failed
    case removed
    case completed

    // 预操作标记，解决操作运行中的任务是异步回调而导致的问题
    case willSuspend
    case willCancel
    case willRemove
}

public enum TRLogLevel {
    case high
    case low
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



extension Int64: TiercelCompatible {}
extension Tiercel where Base == Int64 {

    /// 返回下载速度的字符串，如：1MB/s
    ///
    /// - Returns:
    public func convertSpeedToString() -> String {
        
        let size = convertBytesToString() 
        return [size, "s"].joined(separator: "/")
    }

    /// 返回 00：00格式的字符串
    ///
    /// - Returns:
    public func convertTimeToString() -> String {
        
        let formatter = DateComponentsFormatter()
        
        formatter.unitsStyle = .positional
       
        return formatter.string(from: TimeInterval(base)) ?? ""
    }

    /// 返回字节大小的字符串
    ///
    /// - Returns:
    public func convertBytesToString() -> String {
                
        return ByteCountFormatter.string(fromByteCount: base, countStyle: .file)
    }
}

extension Double: TiercelCompatible {}
extension Tiercel where Base == Double {

    /// - Returns: A formated date with `DateFormatter.Style.medium` for both date and time
    public func convertTimeToDateString() -> String {
        let time = base
        let date = Date(timeIntervalSince1970: time)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

}

extension UIDevice: TiercelCompatible {}
extension Tiercel where Base: UIDevice {
    public var freeDiskSpaceInBytes: Int64 {
        if #available(iOS 11.0, *) {
            if let space = try? URL(fileURLWithPath: NSHomeDirectory() as String).resourceValues(forKeys: [URLResourceKey.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage {
                return space ?? 0
            } else {
                return 0
            }
        } else {
            if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String),
                let freeSpace = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value {
                return freeSpace
            } else {
                return 0
            }
        }
    }
}

extension DispatchQueue: TiercelCompatible {}
extension Tiercel where Base: DispatchQueue {
    internal func safeAsync(_ block: @escaping ()->()) {
        if Thread.isMainThread {
            block()
        } else if base == DispatchQueue.main {
            base.async { block() }
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
}




extension Array {
    public func safeObjectAtIndex(_ index: Int) -> Element? {
        if index < self.count {
            return self[index]
        } else {
            return nil
        }
    }
}


public func TiercelLog<T>(_ message: T, file: String = #file, method: String = #function, line: Int = #line) {
    
    switch TRManager.logLevel {
    case .high:
        print("")
        print("***************TiercelLog****************")
        let threadNum = (Thread.current.description as NSString).components(separatedBy: "{").last?.components(separatedBy: ",").first ?? ""
        
        print("source  :  \((file as NSString).lastPathComponent)[\(line)]\n" +
            "Thread  :  \(threadNum)\n" +
            "Info    :  \(message)"
        )
        print("")
    case .low: print(message)
    case .none: break
    }
}


