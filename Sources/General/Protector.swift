//
//  Protector.swift
//  Tiercel
//
//  Created by Daniels Lau on 2020/1/9.
//  Copyright © 2020 Daniels. All rights reserved.
//

import Foundation


final internal class UnfairLock {
    private let unfairLock: os_unfair_lock_t

    internal init() {
        
        unfairLock = .allocate(capacity: 1)
        unfairLock.initialize(to: os_unfair_lock())
    }

    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }

    private func lock() {
        os_unfair_lock_lock(unfairLock)
    }

    private func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }


    internal func around<T>(_ closure: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try closure()
    }

    internal func around(_ closure: () throws -> Void) rethrows -> Void {
        lock(); defer { unlock() }
        return try closure()
    }
}

final internal class Protector<T> {
    private let lock = UnfairLock()
    private var value: T

    internal init(_ value: T) {
        self.value = value
    }

    internal var directValue: T {
        get { return lock.around { value } }
        set { lock.around { value = newValue } }
    }


    internal func read<U>(_ closure: (T) throws -> U) rethrows -> U {
        return try lock.around { try closure(self.value) }
    }


    @discardableResult
    internal func write<U>(_ closure: (inout T) throws -> U) rethrows -> U {
        return try lock.around { try closure(&self.value) }
    }
}
