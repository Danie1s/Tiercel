//
//  ViewController1.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import Tiercel

class ViewController1: UIViewController {

    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var timeRemainingLabel: UILabel!
    @IBOutlet weak var startDateLabel: UILabel!
    @IBOutlet weak var endDateLabel: UILabel!
    @IBOutlet weak var validationLabel: UILabel!


//    lazy var URLString = "https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/OfficeMac/Microsoft_Office_2016_16.10.18021001_Installer.pkg"
    lazy var URLString = "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg"


    override func viewDidLoad() {
        super.viewDidLoad()

        if let task = TRManager.default.tasks.safeObject(at: 0) as? TRDownloadTask {
            updateUI(task)
        }
    }

    private func updateUI(_ task: TRTask) {
        let per = task.progress.fractionCompleted
        progressLabel.text = "progress： \(String(format: "%.2f", per * 100))%"
        progressView.progress = Float(per)
        speedLabel.text = "speed： \(task.speed.tr.convertSpeedToString())"
        timeRemainingLabel.text = "剩余时间： \(task.timeRemaining.tr.convertTimeToString())"
        startDateLabel.text = "开始时间： \(task.startDate.tr.convertTimeToDateString())"
        endDateLabel.text = "结束时间： \(task.endDate.tr.convertTimeToDateString())"
        var validation: String
        switch task.validation {
        case .unkown:
            validationLabel.textColor = UIColor.blue
            validation = "未知"
        case .correct:
            validationLabel.textColor = UIColor.green
            validation = "正确"
        case .incorrect:
            validationLabel.textColor = UIColor.red
            validation = "错误"
        }
        validationLabel.text = "文件验证： \(validation)"
    }
    
    @IBAction func start(_ sender: UIButton) {
        TRManager.default.download(URLString)?.progress({ [weak self] (task) in
            self?.updateUI(task)
        }).success({ [weak self] (task) in
            self?.updateUI(task)
            if task.status == .succeeded {
                // 下载任务成功了
                
            }
        }).failure({ [weak self] (task) in
            self?.updateUI(task)
            
            if task.status == .suspended {
                // 下载任务暂停了
            }
            if task.status == .failed {
                // 下载任务失败了
            }
            if task.status == .canceled {
                // 下载任务取消了
            }
            if task.status == .removed {
                // 下载任务移除了
            }
        }).validateFile(verificationCode: "9e2a3650530b563da297c9246acaad5c", verificationType: .md5, validateHandler: { [weak self] (task) in
            self?.updateUI(task)
            if task.validation == .correct {
                TiercelLog("文件正确")
            } else {
                TiercelLog("文件错误")
            }
        })
    }

    @IBAction func suspend(_ sender: UIButton) {
        TRManager.default.suspend(URLString)
    }


    @IBAction func cancel(_ sender: UIButton) {
        TRManager.default.cancel(URLString)
    }

    @IBAction func deleteTask(_ sender: UIButton) {
        TRManager.default.remove(URLString, completely: false)
    }

    @IBAction func clearDisk(_ sender: Any) {
        TRManager.default.cache.clearDiskCache()
    }
}

