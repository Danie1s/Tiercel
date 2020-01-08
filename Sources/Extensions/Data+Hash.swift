//
//  Data+Hash.swift
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
import CommonCrypto

extension Data: TiercelCompatible { }
extension TiercelWrapper where Base == Data {
    public var md5: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = base.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            return CC_MD5(bytes.baseAddress, CC_LONG(base.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    public var sha1: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        _ = base.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            return CC_SHA1(bytes.baseAddress, CC_LONG(base.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    public var sha256: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = base.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            return CC_SHA256(bytes.baseAddress, CC_LONG(base.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    public var sha512: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        _ = base.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            return CC_SHA512(bytes.baseAddress, CC_LONG(base.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
}
