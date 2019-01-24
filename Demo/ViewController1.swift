//
//  ViewController1.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018年 Daniels. All rights reserved.
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


    lazy var downloadManager = TRManager()

    lazy var URLString = "https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/OfficeMac/Microsoft_Office_2016_16.10.18021001_Installer.pkg"

    override func viewDidLoad() {
        super.viewDidLoad()
        TRManager.logLevel = .high
    }

    deinit {
        downloadManager.invalidate()
    }


    private func updateUI(_ task: TRTask) {
        let per = task.progress.fractionCompleted
        progressLabel.text = "progress： \(String(format: "%.2f", per * 100))%"
        progressView.progress = Float(per)
        speedLabel.text = "speed： \(task.speed.tr.convertSpeedToString())"
        timeRemainingLabel.text = "剩余时间： \(task.timeRemaining.tr.convertTimeToString())"
        startDateLabel.text = "开始时间： \(task.startDate.tr.convertTimeToDateString())"
        endDateLabel.text = "结束时间： \(task.endDate.tr.convertTimeToDateString())"
    }
    
    @IBAction func start(_ sender: UIButton) {

        downloadManager.download(URLString, progressHandler: { [weak self] (task) in
            self?.updateUI(task)
        }, successHandler: { [weak self] (task) in
            self?.updateUI(task)
            if task.status == .completed {
                // 下载任务完成了
            }
        }, failureHandler: { [weak self] (task) in
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
        })
    }

    @IBAction func suspend(_ sender: UIButton) {
        downloadManager.suspend(URLString)
    }


    @IBAction func cancel(_ sender: UIButton) {
        downloadManager.cancel(URLString)
    }

    @IBAction func deleteTask(_ sender: UIButton) {
        downloadManager.remove(URLString, completely: false)
    }

    @IBAction func clearDisk(_ sender: Any) {
        downloadManager.cache.clearDiskCache()
    }
}

