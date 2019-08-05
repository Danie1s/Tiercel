//
//  Delegate.swift
//  Tiercel
//
//  Created by RecherJ on 2019/8/5.
//  Copyright © 2019 Daniels. All rights reserved.
//

import Foundation

// 一个代理包装，避免循环引用
public class Delegate<Input, Output> {
    
    init() {}
    
    private var block: ((Input) -> Output?)?
    
    func delegate<T: AnyObject>(on target: T, block: ((T, Input) -> Output)?) {
        self.block = { [weak target] input in
            guard let target = target else { return nil }
            return block?(target, input)
        }
    }
    
    func call(_ input: Input) -> Output? {
        return block?(input)
    }
}


extension Delegate where Input == Void {
    func call() -> Output? {
        return call(())
    }
}
