//
//  ViewController1.swift
//  Tiercel-iOS-Demo
//
//  Created by 陈磊 on 2020/8/19.
//  Copyright © 2020 Daniels. All rights reserved.
//

import Cocoa
import Tiercel

class ViewController1: NSViewController {
    
    @IBOutlet weak var speedLabel: NSTextField!
    @IBOutlet weak var progressLabel: NSTextField!
    @IBOutlet weak var progressView: NSProgressIndicator!
    @IBOutlet weak var timeRemainingLabel: NSTextField!
    @IBOutlet weak var startDateLabel: NSTextField!
    @IBOutlet weak var endDateLabel: NSTextField!
    @IBOutlet weak var validationLabel: NSTextField!
    
    //    lazy var URLString = "https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/OfficeMac/Microsoft_Office_2016_16.10.18021001_Installer.pkg"
    lazy var URLString = "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg"
    var sessionManager = appDelegate.sessionManager1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sessionManager.tasks.safeObject(at: 0)?.progress { [weak self] (task) in
            self?.updateUI(task)
        }.completion { [weak self] (task) in
            self?.updateUI(task)
            if task.status == .succeeded {
                // 下载成功
            } else {
                // 其他状态
            }
        }.validateFile(code: "9e2a3650530b563da297c9246acaad5c", type: .md5) { [weak self] (task) in
            self?.updateUI(task)
            if task.validation == .correct {
                // 文件正确
            } else {
                // 文件错误
            }
        }
    }
    
    private func updateUI(_ task: DownloadTask) {
        let per = task.progress.fractionCompleted
        progressLabel.stringValue = "progress： \(String(format: "%.2f", per * 100))%"
        progressView.maxValue = Double(task.progress.totalUnitCount)
        progressView.doubleValue = Double(task.progress.completedUnitCount)
        speedLabel.stringValue = "speed： \(task.speedString)"
        timeRemainingLabel.stringValue = "剩余时间： \(task.timeRemainingString)"
        startDateLabel.stringValue = "开始时间： \(task.startDateString)"
        endDateLabel.stringValue = "结束时间： \(task.endDateString)"
        var validation: String
        switch task.validation {
        case .unkown:
            validationLabel.textColor = NSColor.blue
            validation = "未知"
        case .correct:
            validationLabel.textColor = NSColor.green
            validation = "正确"
        case .incorrect:
            validationLabel.textColor = NSColor.red
            validation = "错误"
        }
        validationLabel.stringValue = "文件验证： \(validation)"
    }
    
    @IBAction func start(_ sender: Any) {
        sessionManager.download(URLString)?.progress { [weak self] (task) in
            self?.updateUI(task)
        }.completion { [weak self] (task) in
            self?.updateUI(task)
            if task.status == .succeeded {
                // 下载成功
            } else {
                // 其他状态
            }
        }.validateFile(code: "9e2a3650530b563da297c9246acaad5c", type: .md5) { [weak self] (task) in
            self?.updateUI(task)
            if task.validation == .correct {
                // 文件正确
            } else {
                // 文件错误
            }
        }
    }
    
    @IBAction func suspend(_ sender: Any) {
        sessionManager.suspend(URLString)
    }
    
    
    @IBAction func cancel(_ sender: Any) {
        sessionManager.cancel(URLString)
    }
    
    @IBAction func deleteTask(_ sender: Any) {
        sessionManager.remove(URLString, completely: false)
    }
    
    @IBAction func clearDisk(_ sender: Any) {
        sessionManager.cache.clearDiskCache()
    }
    
}
