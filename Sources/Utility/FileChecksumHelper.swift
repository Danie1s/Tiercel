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


public enum FileChecksumHelper {
    
    public enum VerificationType : Int {
        case md5
        case sha1
        case sha256
        case sha512
    }
    
    public enum FileVerificationError: Error {
        case codeEmpty
        case codeMismatch(code: String)
        case fileDoesnotExist(path: String)
        case readDataFailed(path: String)
    }
    
    private static let ioQueue: DispatchQueue = DispatchQueue(label: "com.Tiercel.FileChecksumHelper.ioQueue",
                                                              attributes: .concurrent)
    
    
    public static func validateFile(_ filePath: String,
                                   code: String,
                                   type: VerificationType,
                                   completion: @escaping (Result<Bool, FileVerificationError>) -> ()) {
        if code.isEmpty {
            completion(.failure(FileVerificationError.codeEmpty))
            return
        }
        ioQueue.async {
            guard FileManager.default.fileExists(atPath: filePath) else {
                completion(.failure(FileVerificationError.fileDoesnotExist(path: filePath)))
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
                if isCorrect {
                    completion(.success(true))
                } else {
                    completion(.failure(FileVerificationError.codeMismatch(code: code)))
                }
            } catch {
                completion(.failure(FileVerificationError.readDataFailed(path: filePath)))
            }
        }
    }
}



extension FileChecksumHelper.FileVerificationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .codeEmpty:
            return "verification code is empty"
        case let .codeMismatch(code):
            return "verification code mismatch, code: \(code)"
        case let .fileDoesnotExist(path):
            return "file does not exist, path: \(path)"
        case let .readDataFailed(path):
            return "read data failed, path: \(path)"
        }
    }

}


