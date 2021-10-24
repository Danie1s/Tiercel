//
//  DownloadResumeData.swift
//  Tiercel
//
//  Created by Daniels on 2021/10/23.
//  Copyright © 2021 Daniels. All rights reserved.
//

import Foundation

final class DownloadResumeData: Codable {
    
    private enum CodingKeys: CodingKey {
        case data
        case dictionary
    }
    
    private enum Keys {
        static let infoVersionKey = "NSURLSessionResumeInfoVersion"
        static let currentRequestKey = "NSURLSessionResumeCurrentRequest"
        static let originalRequestKey = "NSURLSessionResumeOriginalRequest"
        static let resumeByteRangeKey = "NSURLSessionResumeByteRange"
        static let infoTempFileNameKey = "NSURLSessionResumeInfoTempFileName"
        static let bytesReceivedKey = "NSURLSessionResumeBytesReceived"
        static let downloadURL = "NSURLSessionDownloadURL"
        static let entityTag = "NSURLSessionResumeEntityTag"
        static let serverDownloadDate = "NSURLSessionResumeServerDownloadDate"
        
        static let archiveRootObjectKey = "NSKeyedArchiveRootObjectKey"
    }
    
    let data: Data
    
    private let dictionary: [String: Any]
    
    var tmpFileName: String? {
        dictionary[Keys.infoTempFileNameKey] as? String
    }
    
    var currentRequestData: Data? {
        dictionary[Keys.currentRequestKey] as? Data
    }
    
    var originalRequestData: Data? {
        dictionary[Keys.originalRequestKey] as? Data
    }
    
    init?(data: Data) {
        guard var dictionary = Self.decode(data) else { return nil }
        if #available(iOS 11.3, *) {
        } else if #available(iOS 11.0, *) {
            // 修复 11.0 - 11.2 bug
            dictionary.removeValue(forKey: Keys.resumeByteRangeKey)
        } else if #available(iOS 10.2, *) {
        } else if #available(iOS 10.0, *) {
            // 修复 10.0 - 10.1 bug
            Self.correctRequestDatas(in: &dictionary)
        } else {
        }
        guard let correctData = try? PropertyListSerialization.data(fromPropertyList: dictionary,
                                                                    format: PropertyListSerialization.PropertyListFormat.xml,
                                                                    options: PropertyListSerialization.WriteOptions())
        else {
            return nil
        }
        self.dictionary = dictionary
        self.data = correctData
    }
    

    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode(Data.self, forKey: .data)
        dictionary = Self.decode(data)!
    }
    
    /// 把 resumeData 解析成字典
    ///
    /// - Parameter data:
    /// - Returns:
    private static func decode(_ data: Data) -> [String: Any]? {
        // In beta versions, resumeData is NSKeyedArchive encoded instead of plist
        var object: NSDictionary?
        if #available(OSX 10.11, iOS 9.0, *) {
            let keyedUnarchiver = NSKeyedUnarchiver(forReadingWith: data)
            
            do {
                object = try keyedUnarchiver.decodeTopLevelObject(of: NSDictionary.self, forKey: Keys.archiveRootObjectKey)
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
        if let object = object as? [String: Any] {
            return object
        } else {
            return nil
        }
    }
    
    
    
    
    /// 修复 10.0 - 10.1 resumeData bug
    private static func correctRequestDatas(in resumeDictionary: inout [String: Any]) {
        if let currentRequestData = resumeDictionary[Keys.currentRequestKey] as? Data {
            resumeDictionary[Keys.currentRequestKey] = correctRequestData(currentRequestData)
        }
        if let originalRequestData = resumeDictionary[Keys.originalRequestKey] as? Data {
            resumeDictionary[Keys.originalRequestKey] = correctRequestData(originalRequestData)
        }
    }
    
    /// 修复 resumeData 中的 currentRequest 和 originalRequestData
    private static func correctRequestData(_ requestData: Data) -> Data? {
        if NSKeyedUnarchiver.unarchiveObject(with: requestData) != nil {
            return requestData
        }
        guard let requestDictionary = try? PropertyListSerialization.propertyList(from: requestData,
                                                                                  options: .mutableContainersAndLeaves,
                                                                                  format: nil) as? NSMutableDictionary
        else { return nil }
        // Rectify weird __nsurlrequest_proto_props objects to $number pattern
        var k = 0
        while ((requestDictionary["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "$\(k)") != nil {
            k += 1
        }
        var i = 0
        while ((requestDictionary["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "__nsurlrequest_proto_prop_obj_\(i)") != nil {
            let arr = requestDictionary["$objects"] as? NSMutableArray
            if let dic = arr?[1] as? NSMutableDictionary, let obj = dic["__nsurlrequest_proto_prop_obj_\(i)"] {
                dic.setObject(obj, forKey: "$\(i + k)" as NSString)
                dic.removeObject(forKey: "__nsurlrequest_proto_prop_obj_\(i)")
                arr?[1] = dic
                requestDictionary["$objects"] = arr
            }
            i += 1
        }
        if ((requestDictionary["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "__nsurlrequest_proto_props") != nil {
            let arr = requestDictionary["$objects"] as? NSMutableArray
            if let dic = arr?[1] as? NSMutableDictionary, let obj = dic["__nsurlrequest_proto_props"] {
                dic.setObject(obj, forKey: "$\(i + k)" as NSString)
                dic.removeObject(forKey: "__nsurlrequest_proto_props")
                arr?[1] = dic
                requestDictionary["$objects"] = arr
            }
        }
        
        if let obj = (requestDictionary["$top"] as? NSMutableDictionary)?.object(forKey: Keys.archiveRootObjectKey) as AnyObject? {
            (requestDictionary["$top"] as? NSMutableDictionary)?.setObject(obj, forKey: NSKeyedArchiveRootObjectKey as NSString)
            (requestDictionary["$top"] as? NSMutableDictionary)?.removeObject(forKey: Keys.archiveRootObjectKey)
        }
        // Reencode archived object
        return try? PropertyListSerialization.data(fromPropertyList: requestDictionary,
                                                   format: PropertyListSerialization.PropertyListFormat.binary,
                                                   options: PropertyListSerialization.WriteOptions())
    }
    
    
}
