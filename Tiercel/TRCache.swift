//
//  TRCache.swift
//  Tiercel
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018年 Daniels. All rights reserved.
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

import UIKit

public class TRCache {
    
    public static let `default` = TRCache("default")
    
    private let ioQueue: DispatchQueue
    
    public let downloadPath: String

    internal var isStoreInfo: Bool

    public let downloadTmpPath: String
    
    public let downloadFilePath: String
    
    public let name: String
    
    private let fileManager = FileManager.default
    
    private final class func defaultDiskCachePathClosure(_ cacheName: String) -> String {
        let dstPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        return (dstPath as NSString).appendingPathComponent(cacheName)
    }
    
    // MARK: - life cycle


    /// 初始化方法
    ///
    /// - Parameters:
    ///   - name: 不同的name，代表不同的下载模块，对应的文件放在不同的地方
    ///   - isStoreInfo: 是否把下载任务的相关信息持久化到沙盒，一般由TRManager对象创建时传递
    public init(_ name: String, isStoreInfo: Bool = false) {
        self.name = name

        self.isStoreInfo = isStoreInfo
        
        let ioQueueName = "com.Daniels.Tiercel.Cache.ioQueue.\(name)"
        ioQueue = DispatchQueue(label: ioQueueName)
        
        let cacheName = "com.Daniels.Tiercel.Cache.\(name)"
        
        let diskCachePath = TRCache.defaultDiskCachePathClosure(cacheName)
        
        downloadPath = (diskCachePath as NSString).appendingPathComponent("Downloads")

        downloadTmpPath = (downloadPath as NSString).appendingPathComponent("Tmp")
        
        downloadFilePath = (downloadPath as NSString).appendingPathComponent("File")
                
        createDirectory()
        
    }

}


// MARK: - file
extension TRCache {
    internal func createDirectory() {
        
        if !fileManager.fileExists(atPath: downloadPath) {
            do {
                try fileManager.createDirectory(atPath: downloadPath, withIntermediateDirectories: true, attributes: nil)
            } catch  {
                TiercelLog("createDirectory error: \(error)")
            }
        }
        
        if !fileManager.fileExists(atPath: downloadTmpPath) {
            do {
                try fileManager.createDirectory(atPath: downloadTmpPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                TiercelLog("createDirectory error: \(error)")
            }
        }
        
        if !fileManager.fileExists(atPath: downloadFilePath) {
            do {
                try fileManager.createDirectory(atPath: downloadFilePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                TiercelLog("createDirectory error: \(error)")
            }
        }
    }
    
    
    public func filePtah(fileName: String) -> String? {
        if fileName.isEmpty {
            return nil
        }
        let path = (downloadFilePath as NSString).appendingPathComponent(fileName)
        return path
    }
    
    public func fileURL(fileName: String) -> URL? {
        guard let path = filePtah(fileName: fileName) else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    public func fileExists(fileName: String) -> Bool {
        guard let path = filePtah(fileName: fileName) else { return false }
        return fileManager.fileExists(atPath: path)
    }
    
    public func filePtah(URLString: String) -> String? {
        guard let fileName = URL(string: URLString)?.lastPathComponent else { return nil }
        return filePtah(fileName: fileName)
    }

    public func fileURL(URLString: String) -> URL? {
        guard let path = filePtah(URLString: URLString) else { return nil }
        return URL(fileURLWithPath: path)
    }

    public func fileExists(URLString: String) -> Bool {
        guard let path = filePtah(URLString: URLString) else { return false }
        return fileManager.fileExists(atPath: path)
    }



    
    
    public func clearDiskCache() {
        ioQueue.async {
            guard self.fileManager.fileExists(atPath: self.downloadPath) else { return }
            do {
                try self.fileManager.removeItem(atPath: self.downloadPath)
            } catch {
                TiercelLog("removeItem error: \(error)")
            }
            self.createDirectory()
        }
    }
}


// MARK: - retrieve
extension TRCache {
    internal func retrieveTasks() -> [TRTask] {
        guard let taskInfoArray = retrieveTaskInfos() else { return [TRTask]() }
        return taskInfoArray.map { (info) -> TRDownloadTask in
            
            let url = URL(string: info["URLString"] as! String)!
            
            let headers = info["headers"] as? [String: String]
            
            let task = TRDownloadTask(url, headers: headers, fileName: info["fileName"] as? String, cache: self, isCacheInfo: isStoreInfo)

            task.setValuesForKeys(info)

            task.status = TRStatus(rawValue: info["status"] as! String)!
            task.progress.totalUnitCount = info["totalBytes"] as! Int64
            if task.status == .completed {
                task.progress.completedUnitCount = task.progress.totalUnitCount
            } else {
                let path = (self.downloadTmpPath as NSString).appendingPathComponent(task.fileName)
                if self.fileManager.fileExists(atPath: path) {
                    if let fileInfo = try? FileManager().attributesOfItem(atPath: path), let length = fileInfo[.size] as? Int64 {
                        task.progress.completedUnitCount = length
                    }
                }
            }
            if task.status == .running || task.status == .waiting {
                task.status = .suspended
            }
            storeTaskInfo(task)
            return task
        }
    }
    
    internal func retrieveTaskInfos() -> [[String: Any]]? {
        let path = (downloadPath as NSString).appendingPathComponent(name + "Tasks.plist")
        if fileManager.fileExists(atPath: path) {
            guard let array = NSArray(contentsOfFile: path) as? [[String: Any]] else { return nil }
            return array
        } else {
            return nil
        }
    }

}


// MARK: - store
extension TRCache {
    internal func store(_ task: TRDownloadTask) {
        storeTaskInfo(task)
        storeTmpFile(task)
    }
    
    
    internal func storeTaskInfo(_ task: TRDownloadTask) {
        ioQueue.async {
            guard self.isStoreInfo else { return }
            let info: [String : Any] = ["fileName": task.fileName,
                                        "headers": task.headers ?? [:],
                                        "startDate": task.startDate,
                                        "endDate": task.endDate,
                                        "totalBytes": task.progress.totalUnitCount,
                                        "completedBytes": task.progress.completedUnitCount,
                                        "status": task.status.rawValue,
                                        "URLString": task.URLString]
            let path = (self.downloadPath as NSString).appendingPathComponent("\(self.name)Tasks.plist")
            
            if let taskInfoArray = self.retrieveTaskInfos() {
                var isExists = false
                var newTaskInfoArray = taskInfoArray.map({ (taskInfo) -> [String : Any] in
                    if taskInfo["URLString"] as! String == info["URLString"] as! String {
                        isExists = true
                        return info
                    } else {
                        return taskInfo
                    }
                })
                if !isExists {
                    newTaskInfoArray.append(info)
                }
                (newTaskInfoArray as NSArray).write(toFile: path, atomically: true)
            } else {
                ([info] as NSArray).write(toFile: path, atomically: true)
                
            }

        }

    }
    
    internal func storeTmpFile(_ task: TRDownloadTask) {
        ioQueue.sync {
            if task.fileName.isEmpty { return }
            let path = (self.downloadTmpPath as NSString).appendingPathComponent(task.fileName)
            if self.fileManager.fileExists(atPath: path) {
                let destination = (self.downloadFilePath as NSString).appendingPathComponent(task.fileName)
                do {
                    try self.fileManager.moveItem(atPath: path, toPath: destination)
                } catch {
                    TiercelLog("moveItem error: \(error)")
                }
            }
        }
    }

}


// MARK: - remove
extension TRCache {
    internal func remove(_ task: TRDownloadTask, completely: Bool) {
        removeTmpFile(task)
        removeTaskInfo(task)

        if completely {
            removeFile(task)
        }
    }
    
    internal func removeFile(_ task: TRDownloadTask) {
        ioQueue.async {
            if task.fileName.isEmpty { return }
            let path = (self.downloadFilePath as NSString).appendingPathComponent(task.fileName)
            if self.fileManager.fileExists(atPath: path) {
                do {
                    try self.fileManager.removeItem(atPath: path)
                } catch {
                    TiercelLog("removeItem error: \(error)")
                }
            }
        }
    }
    
    internal func removeTaskInfo(_ task: TRDownloadTask) {
        ioQueue.async {
            guard var taskInfoArray = self.retrieveTaskInfos() else { return }
            let path = (self.downloadPath as NSString).appendingPathComponent("\(self.name)Tasks.plist")
            if let index = taskInfoArray.index(where: { $0["URLString"] as! String == task.URLString }) {
                taskInfoArray.remove(at: index)
                let _ = (taskInfoArray as NSArray).write(toFile: path, atomically: true)
            }
        }
    }
    


    /// 删除保留在本地的缓存文件
    ///
    /// - Parameter task:
    internal func removeTmpFile(_ task: TRDownloadTask) {
        objc_sync_enter(self)
        ioQueue.async {
            if task.fileName.isEmpty { return }
            let path = (self.downloadTmpPath as NSString).appendingPathComponent(task.fileName)
            if self.fileManager.fileExists(atPath: path) {
                do {
                    try self.fileManager.removeItem(atPath: path)
                } catch {
                    TiercelLog("removeItem error: \(error)")
                }
            }
        }
        objc_sync_exit(self)
    }
}


