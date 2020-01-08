//
//  URLSession+ResumeData.swift
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

extension URLSession {
    
    /// 把有bug的resumeData修复，然后创建task
    ///
    /// - Parameter resumeData:
    /// - Returns:
    internal func correctedDownloadTask(withResumeData resumeData: Data) -> URLSessionDownloadTask {
        
        let task = downloadTask(withResumeData: resumeData)
        
        if let resumeDictionary = ResumeDataHelper.getResumeDictionary(resumeData) {
            if task.originalRequest == nil, let originalReqData = resumeDictionary[NSURLSessionResumeOriginalRequest] as? Data, let originalRequest = NSKeyedUnarchiver.unarchiveObject(with: originalReqData) as? NSURLRequest {
                task.setValue(originalRequest, forKey: "originalRequest")
            }
            if task.currentRequest == nil, let currentReqData = resumeDictionary[NSURLSessionResumeCurrentRequest] as? Data, let currentRequest = NSKeyedUnarchiver.unarchiveObject(with: currentReqData) as? NSURLRequest {
                task.setValue(currentRequest, forKey: "currentRequest")
            }
        }
        
        return task
    }
}
