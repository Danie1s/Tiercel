//
//  Cache.swift
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

public class Cache {

    private let ioQueue: DispatchQueue
    
    public let downloadPath: String

    public let downloadTmpPath: String
    
    public let downloadFilePath: String
    
    public let identifier: String
    
    private let fileManager = FileManager.default
    
    private let encoder = PropertyListEncoder()
    
    internal let decoder = PropertyListDecoder()
    
    private final class func defaultDiskCachePathClosure(_ cacheName: String) -> String {
        let dstPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        return (dstPath as NSString).appendingPathComponent(cacheName)
    }
    
    
    /// 初始化方法
    ///
    /// - Parameters:
    ///   - name: 不同的name，代表不同的下载模块，对应的文件放在不同的地方
    public init(_ name: String) {

        self.identifier = name
        
        let ioQueueName = "com.Tiercel.Cache.ioQueue.\(name)"
        ioQueue = DispatchQueue(label: ioQueueName)
        
        let cacheName = "com.Daniels.Tiercel.Cache.\(name)"
        
        let diskCachePath = Cache.defaultDiskCachePathClosure(cacheName)
        
        downloadPath = (diskCachePath as NSString).appendingPathComponent("Downloads")

        downloadTmpPath = (downloadPath as NSString).appendingPathComponent("Tmp")
        
        downloadFilePath = (downloadPath as NSString).appendingPathComponent("File")
        
        createDirectory()

        decoder.userInfo[.cache] = self
        
    }

}


// MARK: - file
extension Cache {
    internal func createDirectory() {

        if !fileManager.fileExists(atPath: downloadTmpPath) {
            do {
                try fileManager.createDirectory(atPath: downloadTmpPath, withIntermediateDirectories: true, attributes: nil)
            } catch  {
                TiercelLog("createDirectory error: \(error)", identifier: identifier)
            }
        }
        
        if !fileManager.fileExists(atPath: downloadFilePath) {
            do {
                try fileManager.createDirectory(atPath: downloadFilePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                TiercelLog("createDirectory error: \(error)", identifier: identifier)
            }
        }
    }
    
    
    public func filePath(fileName: String) -> String? {
        if fileName.isEmpty {
            return nil
        }
        let path = (downloadFilePath as NSString).appendingPathComponent(fileName)
        return path
    }
    
    public func fileURL(fileName: String) -> URL? {
        guard let path = filePath(fileName: fileName) else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    public func fileExists(fileName: String) -> Bool {
        guard let path = filePath(fileName: fileName) else { return false }
        return fileManager.fileExists(atPath: path)
    }
    
    public func filePath(url: URLConvertible) -> String? {
        do {
            let validURL = try url.asURL()
            let fileName = validURL.tr.fileName
            return filePath(fileName: fileName)
        } catch {
            return nil
        }
    }
    
    public func fileURL(url: URLConvertible) -> URL? {
        guard let path = filePath(url: url) else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    public func fileExists(url: URLConvertible) -> Bool {
        guard let path = filePath(url: url) else { return false }
        return fileManager.fileExists(atPath: path)
    }
    
    
    
    public func clearDiskCache(onMainQueue: Bool = true, _ handler: Handler<Cache>? = nil) {
        ioQueue.async {
            guard self.fileManager.fileExists(atPath: self.downloadPath) else { return }
            do {
                try self.fileManager.removeItem(atPath: self.downloadPath)
            } catch {
                TiercelLog("removeItem error: \(error)", identifier: self.identifier)
            }
            self.createDirectory()
            if let handler = handler {
                Executer(onMainQueue: onMainQueue, handler: handler).execute(self)
            }
        }
    }
}


// MARK: - retrieve
extension Cache {
    internal func retrieveAllTasks() -> [DownloadTask] {
        return ioQueue.sync {
            var path = (downloadPath as NSString).appendingPathComponent("\(identifier)_Tasks.plist")
            var tasks: [DownloadTask]
            if fileManager.fileExists(atPath: path) {
                do {
                    let url = URL(fileURLWithPath: path)
                    let data = try Data(contentsOf: url)
                    tasks = try decoder.decode([DownloadTask].self, from: data)
                } catch  {
                    TiercelLog("retrieveAllTasks error: \(error)", identifier: identifier)
                    return [DownloadTask]()
                }
            } else {
                path = (downloadPath as NSString).appendingPathComponent("\(identifier)Tasks.plist")
                tasks = NSKeyedUnarchiver.unarchiveObject(withFile: path) as? [DownloadTask] ?? [DownloadTask]()
            }
            tasks.forEach { (task) in
                task.cache = self
                if task.status == .waiting  {
                    task.status = .suspended
                }
            }
            return tasks
        }
    }

    internal func retrieveTmpFile(_ task: DownloadTask) {
        ioQueue.sync {
            guard let tmpFileName = task.tmpFileName, !tmpFileName.isEmpty else { return }
            let path1 = (downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
            let path2 = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            guard fileManager.fileExists(atPath: path1) else { return }

            if fileManager.fileExists(atPath: path2) {
                do {
                    try fileManager.removeItem(atPath: path1)
                } catch {
                    TiercelLog("removeItem error: \(error)", identifier: identifier)
                }
            } else {
                do {
                    try fileManager.moveItem(atPath: path1, toPath: path2)
                } catch {
                    TiercelLog("moveItem error: \(error)", identifier: identifier)
                }
            }
        }
    }


}


// MARK: - store
extension Cache {
    internal func storeTasks(_ tasks: [DownloadTask]) {
        ioQueue.sync {
            do {
                let data = try encoder.encode(tasks)
                var path = (downloadPath as NSString).appendingPathComponent("\(identifier)_Tasks.plist")
                let url = URL(fileURLWithPath: path)
                try data.write(to: url)
                path = (downloadPath as NSString).appendingPathComponent("\(identifier)Tasks.plist")
                try? fileManager.removeItem(atPath: path)
            } catch {
                TiercelLog("storeTasks error: \(error)", identifier: identifier)
            }
        }
    }
    
    internal func storeFile(_ task: DownloadTask) {
        ioQueue.sync {
            guard let location = task.tmpFileURL else { return }
            let destination = (downloadFilePath as NSString).appendingPathComponent(task.fileName)
            do {
                try fileManager.moveItem(at: location, to: URL(fileURLWithPath: destination))
            } catch {
                TiercelLog("moveItem error: \(error)", identifier: identifier)
            }
        }
    }
    
    internal func storeTmpFile(_ task: DownloadTask) {
        ioQueue.sync {
            guard let tmpFileName = task.tmpFileName, !tmpFileName.isEmpty else { return }
            let tmpPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            let destination = (downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
            if fileManager.fileExists(atPath: destination) {
                do {
                    try fileManager.removeItem(atPath: destination)
                } catch {
                    TiercelLog("removeItem error: \(error)", identifier: identifier)
                }
            }
            if fileManager.fileExists(atPath: tmpPath) {
                do {
                    try fileManager.copyItem(atPath: tmpPath, toPath: destination)
                } catch {
                    TiercelLog("copyItem error: \(error)", identifier: identifier)
                }
            }
        }
    }
    
    internal func updateFileName(_ task: DownloadTask, _ newFileName: String) {
        ioQueue.sync {
            if fileManager.fileExists(atPath: task.filePath) {
                do {
                    try fileManager.moveItem(atPath: task.filePath, toPath: filePath(fileName: newFileName)!)
                } catch {
                    TiercelLog("updateFileName error: \(error)", identifier: identifier)
                }
            }
        }
    }
}


// MARK: - remove
extension Cache {
    internal func remove(_ task: DownloadTask, completely: Bool) {
        removeTmpFile(task)
        
        if completely {
            removeFile(task)
        }
    }
    
    internal func removeFile(_ task: DownloadTask) {
        ioQueue.async {
            if task.fileName.isEmpty { return }
            let path = (self.downloadFilePath as NSString).appendingPathComponent(task.fileName)
            if self.fileManager.fileExists(atPath: path) {
                do {
                    try self.fileManager.removeItem(atPath: path)
                } catch {
                    TiercelLog("removeItem error: \(error)", identifier: self.identifier)
                }
            }
        }
    }
    

    
    /// 删除保留在本地的缓存文件
    ///
    /// - Parameter task:
    internal func removeTmpFile(_ task: DownloadTask) {
        ioQueue.async {
            guard let tmpFileName = task.tmpFileName, !tmpFileName.isEmpty else { return }
            let path1 = (self.downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
            let path2 = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            [path1, path2].forEach { (path) in
                if self.fileManager.fileExists(atPath: path) {
                    do {
                        try self.fileManager.removeItem(atPath: path)
                    } catch {
                        TiercelLog("removeItem error: \(error)", identifier: self.identifier)
                    }
                }
            }

        }
    }
}

extension URL: TiercelCompatible { }
extension TiercelWrapper where Base == URL {
    public var fileName: String {
        var fileName = base.absoluteString.tr.md5
        if !base.pathExtension.isEmpty {
            fileName += ".\(base.pathExtension)"
        }
        return fileName
    }
}
