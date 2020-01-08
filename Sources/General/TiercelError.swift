//
//  TiercelError.swift
//  Tiercel
//
//  Created by Daniels Lau on 2019/5/14.
//  Copyright © 2019 Daniels. All rights reserved.
//

import Foundation

public enum TiercelError: Error {
    case invalidURL(url: URLConvertible)
    
}
