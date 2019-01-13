//
//  TRResumeDataHelper.swift
//  BackgroundURLSession
//
//  Created by Daniels Lau on 2019/1/7.
//  Copyright © 2019 Daniels Lau. All rights reserved.
//

import UIKit

internal let NSURLSessionResumeInfoVersion = "NSURLSessionResumeInfoVersion"
internal let NSURLSessionResumeCurrentRequest = "NSURLSessionResumeCurrentRequest"
internal let NSURLSessionResumeOriginalRequest = "NSURLSessionResumeOriginalRequest"
internal let NSURLSessionResumeByteRange = "NSURLSessionResumeByteRange"
internal let NSURLSessionResumeInfoTempFileName = "NSURLSessionResumeInfoTempFileName"
internal let NSURLSessionResumeInfoLocalPath = "NSURLSessionResumeInfoLocalPath"
internal let NSURLSessionResumeBytesReceived = "NSURLSessionResumeBytesReceived"


internal class TRResumeDataHelper {
    
    internal class func handleResumeData(_ data: Data) -> Data? {
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
    internal class func deleteResumeByteRange(_ data: Data) -> Data? {
        guard let resumeDictionary = getResumeDictionary(data) else { return nil }
        resumeDictionary.removeObject(forKey: NSURLSessionResumeByteRange)
        let result = try? PropertyListSerialization.data(fromPropertyList: resumeDictionary, format: PropertyListSerialization.PropertyListFormat.xml, options: PropertyListSerialization.WriteOptions())
        return result
    }
    
    
    /// 修复 10.0 - 10.1 resumeData bug
    ///
    /// - Parameter data:
    /// - Returns:
    internal class func correctResumeData(_ data: Data) -> Data? {
        guard let resumeDictionary = getResumeDictionary(data) else { return nil }
        
        resumeDictionary[NSURLSessionResumeCurrentRequest] = correct(requestData: resumeDictionary[NSURLSessionResumeCurrentRequest] as? Data)
        resumeDictionary[NSURLSessionResumeOriginalRequest] = correct(requestData: resumeDictionary[NSURLSessionResumeOriginalRequest] as? Data)
        
        let result = try? PropertyListSerialization.data(fromPropertyList: resumeDictionary, format: PropertyListSerialization.PropertyListFormat.xml, options: PropertyListSerialization.WriteOptions())
        return result
    }
    
    
    /// 把resumeData解析成字典
    ///
    /// - Parameter data:
    /// - Returns:
    internal class func getResumeDictionary(_ data: Data) -> NSMutableDictionary? {
        // In beta versions, resumeData is NSKeyedArchive encoded instead of plist
        var resumeDictionary: NSMutableDictionary?
        if #available(OSX 10.11, iOS 9.0, *) {
            let keyedUnarchiver = NSKeyedUnarchiver(forReadingWith: data)
            
            do {
                resumeDictionary = try keyedUnarchiver.decodeTopLevelObject(of: NSMutableDictionary.self, forKey: "NSKeyedArchiveRootObjectKey") ?? nil
                if resumeDictionary == nil {
                    resumeDictionary = try keyedUnarchiver.decodeTopLevelObject(of: NSMutableDictionary.self, forKey: NSKeyedArchiveRootObjectKey)            }
            } catch {}
            keyedUnarchiver.finishDecoding()
            
        }
        
        if resumeDictionary == nil {
            do {
                resumeDictionary = try PropertyListSerialization.propertyList(from: data, options: PropertyListSerialization.ReadOptions(), format: nil) as? NSMutableDictionary;
            } catch {}
        }
        
        return resumeDictionary
    }
    
    internal class func getTmpFileName(_ data: Data) -> String? {
        guard let resumeDictionary = TRResumeDataHelper.getResumeDictionary(data), let version = resumeDictionary[NSURLSessionResumeInfoVersion] as? Int else { return nil }
        if version > 1 {
            return resumeDictionary[NSURLSessionResumeInfoTempFileName] as? String
        } else {
            guard let path = resumeDictionary[NSURLSessionResumeInfoLocalPath] as? String else { return nil }
            let url = URL(fileURLWithPath: path)
            return url.lastPathComponent
        }

    }
    
    
    /// 修复resumeData中的当前请求数据和原始请求数据
    ///
    /// - Parameter data:
    /// - Returns:
    internal class func correct(requestData data: Data?) -> Data? {
        guard let data = data else {
            return nil
        }
        if NSKeyedUnarchiver.unarchiveObject(with: data) != nil {
            return data
        }
        guard let archive = (try? PropertyListSerialization.propertyList(from: data, options: [.mutableContainersAndLeaves], format: nil)) as? NSMutableDictionary else {
            return nil
        }
        // Rectify weird __nsurlrequest_proto_props objects to $number pattern
        var k = 0
        while ((archive["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "$\(k)") != nil {
            k += 1
        }
        var i = 0
        while ((archive["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "__nsurlrequest_proto_prop_obj_\(i)") != nil {
            let arr = archive["$objects"] as? NSMutableArray
            if let dic = arr?[1] as? NSMutableDictionary, let obj = dic["__nsurlrequest_proto_prop_obj_\(i)"] {
                dic.setObject(obj, forKey: "$\(i + k)" as NSString)
                dic.removeObject(forKey: "__nsurlrequest_proto_prop_obj_\(i)")
                arr?[1] = dic
                archive["$objects"] = arr
            }
            i += 1
        }
        if ((archive["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "__nsurlrequest_proto_props") != nil {
            let arr = archive["$objects"] as? NSMutableArray
            if let dic = arr?[1] as? NSMutableDictionary, let obj = dic["__nsurlrequest_proto_props"] {
                dic.setObject(obj, forKey: "$\(i + k)" as NSString)
                dic.removeObject(forKey: "__nsurlrequest_proto_props")
                arr?[1] = dic
                archive["$objects"] = arr
            }
        }
        /* I think we have no reason to keep this section in effect
         for item in (archive["$objects"] as? NSMutableArray) ?? [] {
         if let cls = item as? NSMutableDictionary, cls["$classname"] as? NSString == "NSURLRequest" {
         cls["$classname"] = NSString(string: "NSMutableURLRequest")
         (cls["$classes"] as? NSMutableArray)?.insert(NSString(string: "NSMutableURLRequest"), at: 0)
         }
         }*/
        // Rectify weird "NSKeyedArchiveRootObjectKey" top key to NSKeyedArchiveRootObjectKey = "root"
        if let obj = (archive["$top"] as? NSMutableDictionary)?.object(forKey: "NSKeyedArchiveRootObjectKey") as AnyObject? {
            (archive["$top"] as? NSMutableDictionary)?.setObject(obj, forKey: NSKeyedArchiveRootObjectKey as NSString)
            (archive["$top"] as? NSMutableDictionary)?.removeObject(forKey: "NSKeyedArchiveRootObjectKey")
        }
        // Reencode archived object
        let result = try? PropertyListSerialization.data(fromPropertyList: archive, format: PropertyListSerialization.PropertyListFormat.binary, options: PropertyListSerialization.WriteOptions())
        return result
    }

}


extension URLSession {
    
    /// 把有bug的resumeData修复，然后创建task
    ///
    /// - Parameter resumeData:
    /// - Returns:
    internal func correctedDownloadTask(withResumeData resumeData: Data) -> URLSessionDownloadTask {
        
        let task = downloadTask(withResumeData: resumeData)
        
        // a compensation for inability to set task requests in CFNetwork.
        // While you still get -[NSKeyedUnarchiver initForReadingWithData:]: data is NULL error,
        // this section will set them to real objects
        if let resumeDictionary = TRResumeDataHelper.getResumeDictionary(resumeData) {
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






