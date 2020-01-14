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
    
    internal weak var manager: SessionManager?
    
    private let decoder = PropertyListDecoder()
    
    private static func defaultDiskCachePathClosure(_ cacheName: String) -> String {
        let dstPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        return (dstPath as NSString).appendingPathComponent(cacheName)
    }
    

    /// 初始化方法
    /// - Parameters:
    ///   - identifier: 不同的identifier代表不同的下载模块。如果没有自定义下载目录，Cache会提供默认的目录，这些目录跟identifier相关
    ///   - downloadPath: 存放用于DownloadTask持久化的数据，默认提供的downloadTmpPath、downloadFilePath也是在里面
    ///   - downloadTmpPath: 存放下载中的临时文件
    ///   - downloadFilePath: 存放下载完成后的文件
    public init(_ identifier: String, downloadPath: String? = nil, downloadTmpPath: String? = nil, downloadFilePath: String? = nil) {
        self.identifier = identifier
        
        let ioQueueName = "com.Tiercel.Cache.ioQueue.\(identifier)"
        ioQueue = DispatchQueue(label: ioQueueName)
        
        let cacheName = "com.Daniels.Tiercel.Cache.\(identifier)"
        
        let diskCachePath = Cache.defaultDiskCachePathClosure(cacheName)
                
        let path = downloadPath ?? (diskCachePath as NSString).appendingPathComponent("Downloads")
                
        self.downloadPath = path

        self.downloadTmpPath = downloadTmpPath ?? (path as NSString).appendingPathComponent("Tmp")
        
        self.downloadFilePath = downloadFilePath ?? (path as NSString).appendingPathComponent("File")
        
        createDirectory()

        decoder.userInfo[.cache] = self
        
    }
    
    public func invalidate() {
        decoder.userInfo[.cache] = nil
    }
}


// MARK: - file
extension Cache {
    internal func createDirectory() {
        
        if !fileManager.fileExists(atPath: downloadPath) {
            do {
                try fileManager.createDirectory(atPath: downloadPath, withIntermediateDirectories: true, attributes: nil)
            } catch  {
                manager?.log(.error("create directory failed",
                error: TiercelError.cacheError(reason: .cannotCreateDirectory(path: downloadPath,
                                                                              error: error))))
            }
        }

        if !fileManager.fileExists(atPath: downloadTmpPath) {
            do {
                try fileManager.createDirectory(atPath: downloadTmpPath, withIntermediateDirectories: true, attributes: nil)
            } catch  {
                manager?.log(.error("create directory failed",
                                    error: TiercelError.cacheError(reason: .cannotCreateDirectory(path: downloadTmpPath,
                                                                                                  error: error))))
            }
        }
        
        if !fileManager.fileExists(atPath: downloadFilePath) {
            do {
                try fileManager.createDirectory(atPath: downloadFilePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                manager?.log(.error("create directory failed",
                                    error: TiercelError.cacheError(reason: .cannotCreateDirectory(path: downloadFilePath,
                                                                                                  error: error))))
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
                self.manager?.log(.error("clear disk cache failed",
                                    error: TiercelError.cacheError(reason: .cannotRemoveItem(path: self.downloadPath,
                                                                                                  error: error))))
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
            let path = (downloadPath as NSString).appendingPathComponent("\(identifier)_Tasks.plist")
            if fileManager.fileExists(atPath: path) {
                do {
                    let url = URL(fileURLWithPath: path)
                    let data = try Data(contentsOf: url)
                    let tasks = try decoder.decode([DownloadTask].self, from: data)
                    tasks.forEach { (task) in
                        task.cache = self
                        if task.status == .waiting  {
                            task.protectedState.write { $0.status = .suspended }
                        }
                    }
                    return tasks
                } catch {
                    manager?.log(.error("retrieve all tasks failed", error: TiercelError.cacheError(reason: .cannotRetrieveAllTasks(path: path, error: error))))
                    return [DownloadTask]()
                }
            } else {
               return  [DownloadTask]()
            }
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
                    self.manager?.log(.error("retrieve tmpFile failed",
                                             error: TiercelError.cacheError(reason: .cannotRemoveItem(path: path1,
                                                                                                      error: error))))
                }
            } else {
                do {
                    try fileManager.moveItem(atPath: path1, toPath: path2)
                } catch {
                    self.manager?.log(.error("retrieve tmpFile failed",
                                             error: TiercelError.cacheError(reason: .cannotMoveItem(atPath: path1,
                                                                                                      toPath: path2,
                                                                                                      error: error))))
                }
            }
        }
    }


}


// MARK: - store
extension Cache {
    internal func storeTasks(_ tasks: [DownloadTask]) {
        ioQueue.sync {
            var path = (downloadPath as NSString).appendingPathComponent("\(identifier)_Tasks.plist")
            do {
                let data = try encoder.encode(tasks)
                let url = URL(fileURLWithPath: path)
                try data.write(to: url)
            } catch {
                self.manager?.log(.error("store tasks failed",
                                         error: TiercelError.cacheError(reason: .cannotEncodeTasks(path: path,
                                                                                                error: error))))
            }
            path = (downloadPath as NSString).appendingPathComponent("\(identifier)Tasks.plist")
            try? fileManager.removeItem(atPath: path)
        }
    }
    
    internal func storeFile(_ task: DownloadTask) {
        ioQueue.sync {
            guard let location = task.tmpFileURL else { return }
            let destination = (downloadFilePath as NSString).appendingPathComponent(task.fileName)
            do {
                try fileManager.moveItem(at: location, to: URL(fileURLWithPath: destination))
            } catch {
                self.manager?.log(.error("store file failed",
                                         error: TiercelError.cacheError(reason: .cannotMoveItem(atPath: location.absoluteString,
                                                                                                toPath: destination,
                                                                                                error: error))))
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
                    self.manager?.log(.error("store tmpFile failed",
                                             error: TiercelError.cacheError(reason: .cannotRemoveItem(path: destination,
                                                                                                      error: error))))
                }
            }
            if fileManager.fileExists(atPath: tmpPath) {
                do {
                    try fileManager.copyItem(atPath: tmpPath, toPath: destination)
                } catch {
                    self.manager?.log(.error("store tmpFile failed",
                                             error: TiercelError.cacheError(reason: .cannotCopyItem(atPath: tmpPath,
                                                                                                    toPath: destination,
                                                                                                    error: error))))
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
                    self.manager?.log(.error("update fileName failed",
                                             error: TiercelError.cacheError(reason: .cannotMoveItem(atPath: task.filePath,
                                                                                                      toPath: filePath(fileName: newFileName)!,
                                                                                                      error: error))))
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
                    self.manager?.log(.error("remove file failed",
                                             error: TiercelError.cacheError(reason: .cannotRemoveItem(path: path,
                                                                                                      error: error))))
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
                        self.manager?.log(.error("remove tmpFile failed",
                                                 error: TiercelError.cacheError(reason: .cannotRemoveItem(path: path,
                                                                                                          error: error))))
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
