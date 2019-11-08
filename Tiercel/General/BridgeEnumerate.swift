//
//  BridgeEnumerate.swift
//  Pods-SwiftDownloader_Example
//
//  Created by yw_zhuangtao on 2019/11/4.
//

import Foundation

@objc(BridgeStatus)
public enum BridgeStatus: Int {
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



@objc(BridgeLogLevel)
public enum BridgeLogLevel: Int {
    case detailed
    case simple
    case none
}

@objc(Validation)
public enum Validation: Int {
    case unkown
    case correct
    case incorrect
}
