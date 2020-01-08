//
//  String+Hash.swift
//  Tiercel
//
//  Created by Daniels on 2019/1/22.
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

import Foundation


extension String: TiercelCompatible { }
extension TiercelWrapper where Base == String {
    public var md5: String {
        guard let data = base.data(using: .utf8) else {
            return base
        }
        return data.tr.md5
    }
    
    public var sha1: String {
        guard let data = base.data(using: .utf8) else {
            return base
        }
        return data.tr.sha1
    }
    
    public var sha256: String {
        guard let data = base.data(using: .utf8) else {
            return base
        }
        return data.tr.sha256
    }
    
    public var sha512: String {
        guard let data = base.data(using: .utf8) else {
            return base
        }
        return data.tr.sha512
    }
}
