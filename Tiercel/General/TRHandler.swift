//
//  TRHandler.swift
//  Tiercel
//
//  Created by Daniels Lau on 2019/1/30.
//  Copyright © 2019 Daniels. All rights reserved.
//

import Foundation

public typealias TRHandler<T> = (T) -> ()

public protocol TRHandleable: class {
    associatedtype CompatibleType
    var progressHandler: TRHandler<CompatibleType>? { get set }
    var successHandler: TRHandler<CompatibleType>? { get set }
    var failureHandler: TRHandler<CompatibleType>? { get set }
}

extension TRHandleable {
    @discardableResult
    public func progress(_ handler: @escaping TRHandler<CompatibleType>) -> Self {
        progressHandler = handler
        return self
    }
    
    @discardableResult
    public func success(_ handler: @escaping TRHandler<CompatibleType>) -> Self {
        successHandler = handler
        return self
    }
    
    @discardableResult
    public func failure(_ handler: @escaping TRHandler<CompatibleType>) -> Self {
        failureHandler = handler
        return self
    }
}

extension Array where Element: TRHandleable {
    @discardableResult
    public func progress(_ handler: @escaping TRHandler<Element.CompatibleType>) -> [Element] {
        self.forEach { $0.progress(handler) }
        return self
    }
    
    @discardableResult
    public func success(_ handler: @escaping TRHandler<Element.CompatibleType>) -> [Element] {
        self.forEach { $0.success(handler) }
        return self
    }
    
    @discardableResult
    public func failure(_ handler: @escaping TRHandler<Element.CompatibleType>) -> [Element] {
        self.forEach { $0.failure(handler) }
        return self
    }
}
