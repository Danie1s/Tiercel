//
//  Int64+TaskInfo.swift
//  Tiercel
//
//  Created by Daniels on 2019/1/22.
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

import Foundation

extension Int64: TiercelCompatible {}
extension Tiercel where Base == Int64 {
    
    /// 返回下载速度的字符串，如：1MB/s
    ///
    /// - Returns:
    public func convertSpeedToString() -> String {
        let length = Double(base)
        if length >= pow(1024, 3) {
            return "\(String(format: "%.2f", length / pow(1024, 3)))GB/s"
        } else if length >= pow(1024, 2) {
            return "\(String(format: "%.2f", length / pow(1024, 2)))MB/s"
        } else if length >= 1024 {
            return "\(String(format: "%.0f", length / 1024))KB/s"
        } else {
            return "\(base)B/s"
        }
    }
    
    /// 返回 00：00格式的字符串
    ///
    /// - Returns:
    public func convertTimeToString() -> String {
        let time = Double(base)
        let date = Date(timeIntervalSinceNow: time)
        var timeString = ""
        let calender = Calendar.current
        let set: Set<Calendar.Component> = [.hour, .minute, .second]
        let dateCmp = calender.dateComponents(set, from: Date(), to: date)
        if let hour = dateCmp.hour, let minute = dateCmp.minute, let second = dateCmp.second {
            if hour > 0 {
                timeString = timeString + "\(String(format: "%02d", hour)):"
            }
            timeString = timeString + "\(String(format: "%02d", minute)):"
            timeString = timeString + "\(String(format: "%02d", second))"
        }
        return timeString
    }
    
    /// 返回字节大小的字符串
    ///
    /// - Returns:
    public func convertBytesToString() -> String {
        let length = Double(base)
        if length >= pow(1024, 3) {
            return "\(String(format: "%.2f", length / pow(1024, 3)))GB"
        } else if length >= pow(1024, 2) {
            return "\(String(format: "%.2f", length / pow(1024, 2)))MB"
        } else if length >= 1024 {
            return "\(String(format: "%.0f", length / 1024))KB"
        } else {
            return "\(base)B"
        }
    }
    
    
}
