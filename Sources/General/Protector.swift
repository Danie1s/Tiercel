//
//  Protector.swift
//  Tiercel
//
//  Created by Daniels on 2020/1/9.
//  Copyright © 2020 Daniels. All rights reserved.
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


final public class UnfairLock {
    private let unfairLock: os_unfair_lock_t

    public init() {
        
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


    public func around<T>(_ closure: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try closure()
    }

    public func around(_ closure: () throws -> Void) rethrows -> Void {
        lock(); defer { unlock() }
        return try closure()
    }
}

final public class Protector<T> {
    private let lock = UnfairLock()
    private var value: T

    public init(_ value: T) {
        self.value = value
    }

    public var directValue: T {
        get { return lock.around { value } }
        set { lock.around { value = newValue } }
    }


    public func read<U>(_ closure: (T) throws -> U) rethrows -> U {
        return try lock.around { try closure(self.value) }
    }


    @discardableResult
    public func write<U>(_ closure: (inout T) throws -> U) rethrows -> U {
        return try lock.around { try closure(&self.value) }
    }
}

final public class Debouncer {
    
    private let lock = UnfairLock()
    
    private var queue: DispatchQueue
    
    private var workItems = [String: DispatchWorkItem]()
    
    public init(queue: DispatchQueue) {
        self.queue = queue
    }
    
    
    public func execute(label: String, deadline: DispatchTime, execute work: @escaping @convention(block) () -> Void) {
        execute(label: label, time: deadline, execute: work)
    }
    
    
    public func execute(label: String, wallDeadline: DispatchWallTime, execute work: @escaping @convention(block) () -> Void) {
        execute(label: label, time: wallDeadline, execute: work)
    }
    
    
    private func execute<T: Comparable>(label: String, time: T, execute work: @escaping @convention(block) () -> Void) {
        lock.around {
            workItems[label]?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                work()
                self?.workItems.removeValue(forKey: label)
            }
            workItems[label] = workItem
            if let time = time as? DispatchTime {
                queue.asyncAfter(deadline: time, execute: workItem)
            } else if let time = time as? DispatchWallTime {
                queue.asyncAfter(wallDeadline: time, execute: workItem)
            }
        }
    }
}


