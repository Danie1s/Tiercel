//
//  ViewController.swift
//  Tiercel-Mac-Demo
//
//  Created by 刘小龙 on 2025/8/12.
//  Copyright © 2025 Daniels. All rights reserved.
//

import Cocoa
import Tiercel


class ViewController: NSViewController {
    
    @IBOutlet weak var totalTasksLabel: NSTextField!
    @IBOutlet weak var totalSpeedLabel: NSTextField!
    @IBOutlet weak var timeRemainingLabel: NSTextField!
    @IBOutlet weak var totalProgressLabel: NSTextField!
    
    var sessionManager: SessionManager!
    
    var URLStrings: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        
        URLStrings = [
            "https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Office_16.24.19041401_Installer.pkg",
            "http://dldir1.qq.com/qqfile/QQforMac/QQ_V6.5.2.dmg",
            "http://pcclient.download.youku.com/ikumac/youkumac_1.6.7.04093.dmg?spm=a2hpd.20022519.m_235549.5!2~5~5~5!2~P!3~A&file=youkumac_1.6.7.04093.dmg",
            "https://d1.music.126.net/dmusic/NeteaseCloudMusic_Music_official_3.0.17.2833_arm64.dmg",
//            "https://r1---sn-ni5eln7e.gvt1-cn.com/edgedl/android/studio/install/2025.1.1.13/android-studio-2025.1.1.13-mac_arm.dmg",
        ]
        
        
        var configuration = SessionConfiguration()
        configuration.allowsCellularAccess = true
        
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let cacheURL = homeDirectory.appendingPathComponent("test")


//        let path = Cache.defaultDiskCachePathClosure("Test")
        let cacahe = Cache("ViewController2", downloadPath: cacheURL.path)
        
        let manager = SessionManager("ViewController2", configuration: configuration, cache: cacahe, operationQueue: DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue"))
        sessionManager = manager
        
        
        sessionManager.configuration.maxConcurrentTasksLimit = 10
        
        setupManager()
        updateUI()
    }

   
    func setupUI() {
        
    }
    
    
    func setupManager() {
        
        let tasks = sessionManager.tasks
        
        for task in tasks {
            let status = task.status
            
            let message = """
                --- task \(task.fileName)  ----------------------
                    task.url = \(task.url)
                    task.path = \(task.filePath)
                    status == \(status)
                -------------------------------------------------
                
                """
            print(message)
            
            
        }
        
        // 设置 manager 的回调
        sessionManager.progress { [weak self] (manager) in
            self?.updateUI()
            
        }.completion { [weak self] manager in
            self?.updateUI()
            if manager.status == .succeeded {
                // 下载成功
            } else {
                // 其他状态
            }
        }
    }
    
    func updateUI() {
        totalTasksLabel.stringValue = "\(sessionManager.succeededTasks.count)/\(sessionManager.tasks.count)"
        totalSpeedLabel.stringValue = "\(sessionManager.speedString)"
        timeRemainingLabel.stringValue = "剩余时间： \(sessionManager.timeRemainingString)"
        let per = String(format: "%.2f", sessionManager.progress.fractionCompleted)
        totalProgressLabel.stringValue = "\(per)"
    }
    
    
    
    @IBAction func downAllAction(_ sender: Any) {
        
        var urls = self.URLStrings
        
        print(" now we have \(sessionManager.tasks.count) task")
        
        // url 中不包含 需要去掉
        var taskNeedRemove = [DownloadTask]()
        
        var taskSuccess = [DownloadTask]()
        var taskFailed = [DownloadTask]()
        var taskSuspend = [DownloadTask]()
        
        var taskInRunning = [DownloadTask]()
        
        for task in sessionManager.tasks {
            if urls.contains(task.url.absoluteString) == false {
                taskNeedRemove.append(task)
            }
            
            if task.status == .failed {
                taskFailed.append(task)
            }
            
            if task.status == .succeeded {
                taskSuccess.append(task)
            }
            
            if task.status == .running {
                taskInRunning.append(task)
            }
            
            if task.status == .suspended {
                let progress =  task.progress
                let validation = task.validation
                let total =  progress.totalUnitCount
                let completed =   progress.completedUnitCount
                let p = progress.fractionCompleted
                
                let error = task.error
                
                sessionManager.cache.invalidate()
                
                let message = """
                --------------------------------------
                    validation = \(validation)
                    task progress = \(p)
                    total = \(total)
                    ompleted = \(completed)
                    error = \(error)
                -------------------------------------
                """
                print(message)
                
                taskSuspend.append(task)
            }
        }
        
        for t in taskNeedRemove + taskFailed {
            let message = """
                    will remove task
                    task.url = \(t.url)
                    task.path = \(t.filePath)
                """
            print(message)
            sessionManager.remove(t,completely: false)
        }
        
        Thread.sleep(forTimeInterval: 1)
        print("2 now we have \(sessionManager.tasks.count) task")
        
        // 还没有开始下载 runing 是之前没有下载好的
        for t in taskInRunning  {
            let message = """
                    will remove task for previews running
                    this task should be broken
                    task.url = \(t.url)
                    task.path = \(t.filePath)
                """
            print(message)
            sessionManager.remove(t,completely: false)
        }
        
        Thread.sleep(forTimeInterval: 1)
        print("2 now we have \(sessionManager.tasks.count) task")
        

        for string in URLStrings {
            if let task = sessionManager.fetchTask(string) {
                let status = task.status
                print(" status == \(status)")
                if status == .suspended {
                    sessionManager.remove(string)
                }
            }
        }
        
        
        self.sessionManager?.multiDownload(self.URLStrings) { [weak self] _ in
            self?.updateUI()
            
        
        }
        
        
    }
    
    
    
    @IBAction func totalStart(_ sender: Any) {
        sessionManager.totalStart { [weak self] _ in
             
        }
        
        
    }
    
    @IBAction func totalSuspend(_ sender: Any) {
        sessionManager.totalSuspend() { [weak self] _ in
            
            
        }
    }
    
    @IBAction func totalCancel(_ sender: Any) {
        sessionManager.totalCancel() { [weak self] _ in
            
        }
    }
    
    @IBAction func totalDelete(_ sender: Any) {
        sessionManager.totalRemove(completely: false) { [weak self] _ in
            
        }
    }
    
    @IBAction func clearDisk(_ sender: Any) {
        sessionManager.cache.clearDiskCache()
        updateUI()
    }
    
    
}

