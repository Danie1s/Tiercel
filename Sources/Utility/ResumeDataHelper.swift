//
//  ResumeDataHelper.swift
//  Tiercel
//
//  Created by Daniels on 2019/1/7.
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


internal enum ResumeDataHelper {
    
    static let infoVersionKey = "NSURLSessionResumeInfoVersion"
    static let currentRequestKey = "NSURLSessionResumeCurrentRequest"
    static let originalRequestKey = "NSURLSessionResumeOriginalRequest"
    static let resumeByteRangeKey = "NSURLSessionResumeByteRange"
    static let infoTempFileNameKey = "NSURLSessionResumeInfoTempFileName"
    static let infoLocalPathKey = "NSURLSessionResumeInfoLocalPath"
    static let bytesReceivedKey = "NSURLSessionResumeBytesReceived"
    static let archiveRootObjectKey = "NSKeyedArchiveRootObjectKey"
    
    internal static func handleResumeData(_ data: Data) -> Data? {
        if #available(iOS 11.3, *) {
            return data
        } else if #available(iOS 11.0, *) {
            // 修复 11.0 - 11.2 bug
            return deleteResumeByteRange(data)
        } else if #available(iOS 10.2, *) {
            return data
        } else if #available(iOS 10.0, *) {
            // 修复 10.0 - 10.1 bug
            return correctResumeData(data)
        } else {
            return data
        }
    }
    
    
    /// 修复 11.0 - 11.2 resumeData bug
    ///
    /// - Parameter data:
    /// - Returns:
    private static func deleteResumeByteRange(_ data: Data) -> Data? {
        guard let resumeDictionary = getResumeDictionary(data) else { return nil }
        resumeDictionary.removeObject(forKey: resumeByteRangeKey)
        return try? PropertyListSerialization.data(fromPropertyList: resumeDictionary,
                                                         format: PropertyListSerialization.PropertyListFormat.xml,
                                                         options: PropertyListSerialization.WriteOptions())
    }
    
    
    /// 修复 10.0 - 10.1 resumeData bug
    ///
    /// - Parameter data:
    /// - Returns:
    private static func correctResumeData(_ data: Data) -> Data? {
        guard let resumeDictionary = getResumeDictionary(data) else { return nil }
        
        if let currentRequest = resumeDictionary[currentRequestKey] as? Data {
            resumeDictionary[currentRequestKey] = correct(with: currentRequest)
        }
        if let originalRequest = resumeDictionary[originalRequestKey] as? Data {
            resumeDictionary[originalRequestKey] = correct(with: originalRequest)
        }
        
        return try? PropertyListSerialization.data(fromPropertyList: resumeDictionary,
                                                         format: PropertyListSerialization.PropertyListFormat.xml,
                                                         options: PropertyListSerialization.WriteOptions())
    }
    
    
    /// 把resumeData解析成字典
    ///
    /// - Parameter data:
    /// - Returns:
    internal static func getResumeDictionary(_ data: Data) -> NSMutableDictionary? {
        // In beta versions, resumeData is NSKeyedArchive encoded instead of plist
        var object: NSDictionary?
        if #available(OSX 10.11, iOS 9.0, *) {
            let keyedUnarchiver = NSKeyedUnarchiver(forReadingWith: data)
            
            do {
                object = try keyedUnarchiver.decodeTopLevelObject(of: NSDictionary.self, forKey: archiveRootObjectKey)
                if object == nil {
                    object = try keyedUnarchiver.decodeTopLevelObject(of: NSDictionary.self, forKey: NSKeyedArchiveRootObjectKey)
                }
            } catch {}
            keyedUnarchiver.finishDecoding()
        }
        
        if object == nil {
            do {
                object = try PropertyListSerialization.propertyList(from: data,
                                                                    options: .mutableContainersAndLeaves,
                                                                    format: nil) as? NSDictionary
            } catch {}
        }
        
        if let resumeDictionary = object as? NSMutableDictionary {
            return resumeDictionary
        }
        
        guard let resumeDictionary = object else { return nil }
        return NSMutableDictionary(dictionary: resumeDictionary)

    }
    
    internal static func getTmpFileName(_ data: Data) -> String? {
        guard let resumeDictionary = ResumeDataHelper.getResumeDictionary(data),
            let version = resumeDictionary[infoVersionKey] as? Int
            else { return nil }
        if version > 1 {
            return resumeDictionary[infoTempFileNameKey] as? String
        } else {
            guard let path = resumeDictionary[infoLocalPathKey] as? String else { return nil }
            let url = URL(fileURLWithPath: path)
            return url.lastPathComponent
        }

    }
    
    
    /// 修复resumeData中的当前请求数据和原始请求数据
    ///
    /// - Parameter data:
    /// - Returns:
    private static func correct(with data: Data) -> Data? {
        if NSKeyedUnarchiver.unarchiveObject(with: data) != nil {
            return data
        }
        guard let resumeDictionary = try? PropertyListSerialization.propertyList(from: data,
                                                                                 options: .mutableContainersAndLeaves,
                                                                                 format: nil) as? NSMutableDictionary
            else { return nil }
        // Rectify weird __nsurlrequest_proto_props objects to $number pattern
        var k = 0
        while ((resumeDictionary["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "$\(k)") != nil {
            k += 1
        }
        var i = 0
        while ((resumeDictionary["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "__nsurlrequest_proto_prop_obj_\(i)") != nil {
            let arr = resumeDictionary["$objects"] as? NSMutableArray
            if let dic = arr?[1] as? NSMutableDictionary, let obj = dic["__nsurlrequest_proto_prop_obj_\(i)"] {
                dic.setObject(obj, forKey: "$\(i + k)" as NSString)
                dic.removeObject(forKey: "__nsurlrequest_proto_prop_obj_\(i)")
                arr?[1] = dic
                resumeDictionary["$objects"] = arr
            }
            i += 1
        }
        if ((resumeDictionary["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "__nsurlrequest_proto_props") != nil {
            let arr = resumeDictionary["$objects"] as? NSMutableArray
            if let dic = arr?[1] as? NSMutableDictionary, let obj = dic["__nsurlrequest_proto_props"] {
                dic.setObject(obj, forKey: "$\(i + k)" as NSString)
                dic.removeObject(forKey: "__nsurlrequest_proto_props")
                arr?[1] = dic
                resumeDictionary["$objects"] = arr
            }
        }

        if let obj = (resumeDictionary["$top"] as? NSMutableDictionary)?.object(forKey: archiveRootObjectKey) as AnyObject? {
            (resumeDictionary["$top"] as? NSMutableDictionary)?.setObject(obj, forKey: NSKeyedArchiveRootObjectKey as NSString)
            (resumeDictionary["$top"] as? NSMutableDictionary)?.removeObject(forKey: archiveRootObjectKey)
        }
        // Reencode archived object
        return try? PropertyListSerialization.data(fromPropertyList: resumeDictionary,
                                                   format: PropertyListSerialization.PropertyListFormat.binary,
                                                   options: PropertyListSerialization.WriteOptions())
    }

}








