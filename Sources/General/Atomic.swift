//
//  Atomic.swift
//  Tiercel
//
//  Created by Daniels on 2020/1/8.
//  Copyright © 2020 Daniels. All rights reserved.
//

import Foundation

@propertyWrapper
internal struct Atomic<Value> {
    let semaphore: DispatchSemaphore
    var value: Value

    public init(_ wrappedValue: Value, semaphore: DispatchSemaphore = DispatchSemaphore(value: 1)) {
        self.semaphore = semaphore
        self.value = wrappedValue
    }

    public var wrappedValue: Value {
        get {
            semaphore.wait()
            defer { semaphore.signal() }
            return value
        }
        set {
            semaphore.wait()
            defer { semaphore.signal() }
            value = newValue
        }
    }    
}


