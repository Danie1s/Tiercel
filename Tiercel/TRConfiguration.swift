//
//  TRConfiguration.swift
//  BackgroundURLSession
//
//  Created by Daniels Lau on 2019/1/3.
//  Copyright © 2019 Daniels Lau. All rights reserved.
//

import UIKit

public struct TRConfiguration {
    // 请求超时时间
    public var timeoutIntervalForRequest = 30.0
    
    // 最大并发数
    public var maxConcurrentTasksLimit = Int.max
    
    public var allowsCellularAccess = true
    
//    public var isStartDownloadImmediately = true
    
    public init() {
        
    }
    
}
