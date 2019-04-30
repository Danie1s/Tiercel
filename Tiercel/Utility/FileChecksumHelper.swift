//
//  FileChecksumHelper.swift
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

public enum FileVerificationType : Int {
    case md5
    case sha1
    case sha256
    case sha512
}

public class FileChecksumHelper {
    
    private static let ioQueue: DispatchQueue = DispatchQueue(label: "com.Tiercel.FileChecksumHelper.ioQueue", attributes: .concurrent)
    
    public class func validateFile(_ filePath: String,
                                   code: String,
                                   type: FileVerificationType,
                                   _ completion: @escaping (Bool) -> ()) {
        if code.isEmpty {
            TiercelLog("verification code is empty")
            completion(false)
            return
        }
        ioQueue.async {
            guard FileManager.default.fileExists(atPath: filePath) else {
                TiercelLog("file does not exist, filePath: \(filePath)")
                completion(false)
                return
            }
            let url = URL(fileURLWithPath: filePath)

            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                var string: String
                switch type {
                case .md5:
                    string = data.tr.md5
                case .sha1:
                    string = data.tr.sha1
                case .sha256:
                    string = data.tr.sha256
                case .sha512:
                    string = data.tr.sha512
                }
                let isCorrect = string.lowercased() == code.lowercased()
                completion(isCorrect)
            } catch {
                TiercelLog("can't read data, error: \(error)")
                completion(false)
            }
        }
    }
}






