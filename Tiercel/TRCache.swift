//
//  TRCache.swift
//  BackgroundURLSession
//
//  Created by Daniels Lau on 2019/1/3.
//  Copyright © 2019 Daniels Lau. All rights reserved.
//

import UIKit

public class TRCache {
    
    public static let `default` = TRCache("default")
    
    private let ioQueue: DispatchQueue
    
    public let downloadPath: String
    
    public let downloadResumeDataPath: String
    
    public let downloadTmpPath: String
    
    public let downloadFilePath: String
    
    public let name: String
    
    private let fileManager = FileManager.default
    
    public final class func defaultDiskCachePathClosure(_ cacheName: String) -> String {
        let dstPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        return (dstPath as NSString).appendingPathComponent(cacheName)
    }
    
    
    /// 初始化方法
    ///
    /// - Parameters:
    ///   - name: 设置TRCache对象的名字，一般由TRManager对象创建时传递
    ///   - isStoreInfo: 是否把下载任务的相关信息持久化到沙盒，一般由TRManager对象创建时传递
    public init(_ name: String) {
        self.name = name
        
        let ioQueueName = "com.Daniels.Tiercel.Cache.ioQueue.\(name)"
        ioQueue = DispatchQueue(label: ioQueueName)
        
        let cacheName = "com.Daniels.Tiercel.Cache.\(name)"
        
        let diskCachePath = TRCache.defaultDiskCachePathClosure(cacheName)
        
        downloadPath = (diskCachePath as NSString).appendingPathComponent("Downloads")
        
        downloadResumeDataPath = (downloadPath as NSString).appendingPathComponent("ResumeData")
        
        downloadTmpPath = (downloadPath as NSString).appendingPathComponent("Tmp")
        
        downloadFilePath = (downloadPath as NSString).appendingPathComponent("File")
        
        createDirectory()
        
    }

}


// MARK: - file
extension TRCache {
    internal func createDirectory() {
        
        if !fileManager.fileExists(atPath: downloadResumeDataPath) {
            do {
                try fileManager.createDirectory(atPath: downloadResumeDataPath, withIntermediateDirectories: true, attributes: nil)
            } catch _ {}
        }
        
        if !fileManager.fileExists(atPath: downloadTmpPath) {
            do {
                try fileManager.createDirectory(atPath: downloadTmpPath, withIntermediateDirectories: true, attributes: nil)
            } catch _ {}
        }
        
        if !fileManager.fileExists(atPath: downloadFilePath) {
            do {
                try fileManager.createDirectory(atPath: downloadFilePath, withIntermediateDirectories: true, attributes: nil)
            } catch _ {}
        }
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
    
    
    public func clearDiskCache() {
        ioQueue.async {
            guard self.fileManager.fileExists(atPath: self.downloadPath) else { return }
            try? self.fileManager.removeItem(atPath: self.downloadPath)
            self.createDirectory()
        }
    }
}


// MARK: - retrieve
extension TRCache {
    internal func retrieveAllTasks(_ session: URLSession) -> [TRTask]? {
        let path = (self.downloadPath as NSString).appendingPathComponent("\(self.name)Tasks.plist")
        
        let tasks = NSKeyedUnarchiver.unarchiveObject(withFile: path) as? [TRTask]
        tasks?.forEach({ (task) in
            task.session = session
            if task.status == .waiting || task.status == .running {
                task.status = .suspended
            }
        })
        return tasks
    }
}


// MARK: - store
extension TRCache {
    internal func storeTasks(_ tasks: [TRTask]) {
        ioQueue.sync {
            let path = (self.downloadPath as NSString).appendingPathComponent("\(self.name)Tasks.plist")
            NSKeyedArchiver.archiveRootObject(tasks, toFile: path)
        }
    }
    
    internal func storeFile(_ task: TRDownloadTask) {
        ioQueue.sync {
            guard let location = task.location else { return }
            let destination = (self.downloadFilePath as NSString).appendingPathComponent(task.fileName)
            do {
                try self.fileManager.moveItem(at: location, to: URL(fileURLWithPath: destination))
            } catch {
                TiercelLog(error)
                // 错误处理
            }
        }
    }
    
    internal func storeTmpFile(_ task: TRDownloadTask) {
        ioQueue.sync {
            guard let tmpFileName = task.tmpFileName, !tmpFileName.isEmpty else { return }
            let tmpPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            if self.fileManager.fileExists(atPath: tmpPath) {
                let destination = (self.downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
                try? self.fileManager.copyItem(atPath: tmpPath, toPath: destination)
            }
        }
    }
    
    
}


// MARK: - remove
extension TRCache {
    internal func remove(_ task: TRDownloadTask, completely: Bool) {
        removeTmpFile(task)
        
        if completely {
            removeFile(task)
        }
    }
    
    internal func removeFile(_ task: TRDownloadTask) {
        ioQueue.async {
            if task.fileName.isEmpty { return }
            let path = (self.downloadFilePath as NSString).appendingPathComponent(task.fileName)
            if self.fileManager.fileExists(atPath: path) {
                try? self.fileManager.removeItem(atPath: path)
            }
        }
    }
    

    
    /// 删除保留在本地的缓存文件
    ///
    /// - Parameter task:
    internal func removeTmpFile(_ task: TRDownloadTask) {
        ioQueue.async {
            guard let tmpFileName = task.tmpFileName, !tmpFileName.isEmpty else { return }
            let path1 = (self.downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
            if self.fileManager.fileExists(atPath: path1) {
                try? self.fileManager.removeItem(atPath: path1)
            }
            
            let path2 = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            if self.fileManager.fileExists(atPath: path2) {
                try? self.fileManager.removeItem(atPath: path2)
            }
        }
    }
}
