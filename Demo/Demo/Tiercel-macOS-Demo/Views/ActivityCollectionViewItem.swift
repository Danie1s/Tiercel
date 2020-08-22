//
//  ActivityCollectionViewItem.swift
//  Octofile
//
//  Created by 陈磊 on 2020/6/7.
//  Copyright © 2020 Hypobenthos. All rights reserved.
//

import Cocoa
import CoreServices
import Tiercel

class ActivityCollectionViewItem: NSCollectionViewItem {
        
    @IBOutlet weak var logoImageView: NSImageView!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var speedLabel: NSTextField!
    @IBOutlet weak var bytesLabel: NSTextField!
    @IBOutlet weak var controlButton: NSButton!
    @IBOutlet weak var progressView: NSProgressIndicator!
    @IBOutlet weak var timeRemainingLabel: NSTextField!
    @IBOutlet weak var startDateLabel: NSTextField!
    @IBOutlet weak var endDateLabel: NSTextField!
    @IBOutlet weak var statusLabel: NSTextField!
    
    
    
    var tapClosure: ((ActivityCollectionViewItem) -> Void)?


    @IBAction func didTapButton(_ sender: Any) {
        tapClosure?(self)
    }

    func updateProgress(_ task: DownloadTask) {
        
        let pathExtension = task.url.pathExtension
        if let UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                           pathExtension as CFString, nil)?.takeRetainedValue() as String? {
            let icon = NSWorkspace.shared.icon(forFileType: UTI)
            logoImageView.image = icon
        } else {
            logoImageView.image = nil
        }

        progressView.maxValue = Double(task.progress.totalUnitCount)
        progressView.doubleValue = Double(task.progress.completedUnitCount)
        bytesLabel.stringValue = "\(task.progress.completedUnitCount.tr.convertBytesToString())/\(task.progress.totalUnitCount.tr.convertBytesToString())"
        speedLabel.stringValue = task.speedString
        timeRemainingLabel.stringValue = "剩余时间：\(task.timeRemainingString)"
        startDateLabel.stringValue = "开始时间：\(task.startDateString)"
        endDateLabel.stringValue = "结束时间：\(task.endDateString)"
        
        var image = #imageLiteral(resourceName: "suspend")
        switch task.status {
        case .suspended:
            statusLabel.stringValue = "暂停"
            statusLabel.textColor = .black
        case .running:
            image = #imageLiteral(resourceName: "resume")
            statusLabel.stringValue = "下载中"
            statusLabel.textColor = .blue
        case .succeeded:
            statusLabel.stringValue = "成功"
            statusLabel.textColor = .green
        case .failed:
            statusLabel.stringValue = "失败"
            statusLabel.textColor = .red
        case .waiting:
            statusLabel.stringValue = "等待中"
            statusLabel.textColor = .orange
        default:
            image = controlButton.image ?? #imageLiteral(resourceName: "suspend")
            break
        }
        controlButton.image = image
    }
}
