//
//  CodingUserInfoKey+Cache.swift
//  Tiercel
//
//  Created by Daniels on 2019/5/15.
//  Copyright © 2019 Daniels. All rights reserved.
//

import Foundation

extension CodingUserInfoKey {

    internal static let cache = CodingUserInfoKey(rawValue: "com.Tiercel.CodingUserInfoKey.cache")!

    internal static let operationQueue = CodingUserInfoKey(rawValue: "com.Tiercel.CodingUserInfoKey.operationQueue")!
}
