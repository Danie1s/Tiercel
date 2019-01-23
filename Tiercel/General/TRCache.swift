//
//  TRCache.swift
//  Tiercel
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
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

    public let downloadTmpPath: String
    
    public let downloadFilePath: String
    
    public let name: String
    
    private let fileManager = FileManager.default
    
    private final class func defaultDiskCachePathClosure(_ cacheName: String) -> String {
        let dstPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        return (dstPath as NSString).appendingPathComponent(cacheName)
    }
    
    
    /// 初始化方法
    ///
    /// - Parameters:
    ///   - name: 不同的name，代表不同的下载模块，对应的文件放在不同的地方
    public init(_ name: String) {
        self.name = name
        
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

        if !fileManager.fileExists(atPath: downloadTmpPath) {
            do {
                try fileManager.createDirectory(atPath: downloadTmpPath, withIntermediateDirectories: true, attributes: nil)
            } catch  {
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
        guard let url = URL(string: URLString) else { return nil }
        let fileName = url.tr.fileName
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
    internal func retrieveAllTasks() -> [TRTask]? {
        let path = (self.downloadPath as NSString).appendingPathComponent("\(self.name)Tasks.plist")
        
        let tasks = NSKeyedUnarchiver.unarchiveObject(withFile: path) as? [TRTask]
        tasks?.forEach({ (task) in
            task.cache = self
            if task.status == .waiting || task.status == .running {
                task.status = .suspended
            }
        })
        return tasks
    }

    internal func retrievTmpFile(_ task: TRDownloadTask) {
        ioQueue.sync {
            guard let tmpFileName = task.tmpFileName, !tmpFileName.isEmpty else { return }
            let path1 = (self.downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
            let path2 = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            if self.fileManager.fileExists(atPath: path1) && !self.fileManager.fileExists(atPath: path2) {
                do {
                    try self.fileManager.moveItem(atPath: path1, toPath: path2)
                } catch {
                    TiercelLog("moveItem error: \(error)")
                }
            }
        }
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
            guard let location = task.tmpFileURL else { return }
            let destination = (self.downloadFilePath as NSString).appendingPathComponent(task.fileName)
            do {
                try self.fileManager.moveItem(at: location, to: URL(fileURLWithPath: destination))
            } catch {
                TiercelLog("moveItem error: \(error)")
            }
        }
    }
    
    internal func storeTmpFile(_ task: TRDownloadTask) {
        ioQueue.sync {
            guard let tmpFileName = task.tmpFileName, !tmpFileName.isEmpty else { return }
            let tmpPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            let destination = (self.downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
            if self.fileManager.fileExists(atPath: destination) {
                do {
                    try self.fileManager.removeItem(atPath: destination)
                } catch {
                    TiercelLog("removeItem error: \(error)")
                }
            }
            if self.fileManager.fileExists(atPath: tmpPath) {
                do {
                    try self.fileManager.copyItem(atPath: tmpPath, toPath: destination)
                } catch {
                    TiercelLog("copyItem error: \(error)")
                }
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
                do {
                    try self.fileManager.removeItem(atPath: path)
                } catch {
                    TiercelLog("removeItem error: \(error)")
                }
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
                do {
                    try self.fileManager.removeItem(atPath: path1)
                } catch {
                    TiercelLog("removeItem error: \(error)")
                }
            }

            let path2 = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            if self.fileManager.fileExists(atPath: path2) {
                do {
                    try self.fileManager.removeItem(atPath: path2)
                } catch {
                    TiercelLog("removeItem error: \(error)")
                }
            }
        }
    }
}

extension URL: TiercelCompatible { }
extension Tiercel where Base == URL {
    public var fileName: String {
        var fileName = base.absoluteString.tr.md5
        if !base.pathExtension.isEmpty {
            fileName += ".\(base.pathExtension)"
        }
        return fileName
    }
}
