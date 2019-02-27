//
//  TRConfiguration.swift
//  Tiercel
//
//  Created by Daniels on 2019/1/3.
//  Copyright © 2019 Daniels. All rights reserved.
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

protocol Configuration {
    // 请求超时时间
    var timeoutIntervalForRequest: Double { get }
    
    // 最大并发数
    var maxConcurrentTasksLimit: Int { get }
    
    // 是否允许蜂窝网络下载
    var allowsCellularAccess: Bool { get }
}

public struct TRDefaultConfiguration: Configuration {
    public let timeoutIntervalForRequest: Double
    
    public let maxConcurrentTasksLimit: Int
    
    public let allowsCellularAccess: Bool
    
    init(timeoutIntervalForRequest: Double = 30.0,
                maxConcurrentTasksLimit: Int = Int.max,
                allowsCellularAccess: Bool = false) {
        self.timeoutIntervalForRequest = timeoutIntervalForRequest
        self.maxConcurrentTasksLimit = maxConcurrentTasksLimit
        self.allowsCellularAccess = allowsCellularAccess
    }
    
}
